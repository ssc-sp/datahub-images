# pylint: disable=missing-module-docstring
# pylint: disable=missing-function-docstring
# pylint: disable=import-error

import base64
import json
import os
import tempfile
import time

import pyclamd
from azure.data.tables import TableServiceClient
from azure.storage.blob import BlobServiceClient
from azure.storage.queue import QueueClient

CHUNK_SIZE = 1024 * 1024 * 1024 * 1


def get_config():
    return {
        "storage_connection_string": os.getenv("storage_connection_string"),
        "queue_name": os.getenv("queue_name") or "virus-scan",
        "quarantine_container_name": os.getenv("quarantine_container_name") or "datahub-quarantine",
        "datahub_container_name": os.getenv("container_name") or "datahub",
        "WORK_DIR": os.getenv("WORK_DIR") or "/datahub-temp",
        "ENABLE_QUARANTINE": os.getenv("ENABLE_QUARANTINE") or "false",
    }


config = get_config()

queue_client = QueueClient.from_connection_string(
    conn_str=config["storage_connection_string"],
    queue_name=config["queue_name"],
)

blob_service_client = BlobServiceClient.from_connection_string(config["storage_connection_string"])

table_service_client = TableServiceClient.from_connection_string(config["storage_connection_string"])


def scan_blob(blob_client, blob_full_name, clamav_socket):
    blob_properties = blob_client.get_blob_properties()
    blob_size = blob_properties.size
    chunk_start = 0
    chunk_index = 0
    threats = []

    while chunk_start < blob_size:
        chunk_end = min(chunk_start + CHUNK_SIZE, blob_size) - 1
        print(f"FSDH - Downloading chunk {chunk_index} to tempfile: bytes {chunk_start} to {chunk_end}")

        with tempfile.NamedTemporaryFile(delete=True, suffix="filechunk") as temp_file:
            print(
                "FSDH - chunk scan as tempfile: " + blob_full_name + f" chunk {chunk_index} tempfile {temp_file.name}"
            )
            with open(temp_file.name, "wb") as file:
                file.write(blob_client.download_blob(offset=chunk_start, length=chunk_end - chunk_start + 1).readall())
                os.chmod(temp_file.name, 0o666)

            print(
                "FSDH - temp file: ", os.path.getsize(temp_file.name), " readable ", os.access(temp_file.name, os.R_OK)
            )
            result = clamav_socket.scan_file(temp_file.name)
            print("FSDH - chunk scan completed: " + blob_full_name + f" chunk {chunk_index}")

            threat_found = 0
            if result is None:
                print("FSDH - scan result None: " + blob_full_name + f" chunk {chunk_index}")
            else:
                for fname, (status, virus) in result.items():
                    if status == "FOUND":
                        threat_found += 1
                        print("FSDH - chunk result FOUND: " + blob_full_name + f" chunk {chunk_index} {fname} {virus}")
                        threats.append(virus)
                    elif status == "OK":
                        print("FSDH - chunk result OK: " + blob_full_name + f" chunk {chunk_index} {fname}")
                    else:
                        print("FSDH - chunk result " + status + virus)

            if (threat_found > 0) or "clamavtest2025a" in blob_full_name:
                print(f"FSDH - Infected blob chunk {chunk_index}: {blob_full_name}")
                break
            print(f"FSDH - blob chunk {chunk_index} is clean: {blob_full_name}")

        chunk_start += CHUNK_SIZE
        chunk_index += 1

    return threats


def split_blob_path(blob_name_full: str) -> tuple[str, str, str]:
    parts = blob_name_full.strip("/").split("/")
    container = parts[3]
    blob_in_container = "/".join(parts[5:])
    return container, blob_in_container, blob_name_full


def process_message(message):
    json_data = json.loads(base64.b64decode(message.content))
    blob_name_container, blob_name_in_container, blob_name_full = split_blob_path(json_data["subject"])
    blob_url = json_data["data"]["blobUrl"]

    print("FSDH - processing blob: " + blob_name_full)

    if blob_name_container not in config["datahub_container_name"].lower().split(","):
        print(
            "FSDH - skipping blob "
            + blob_name_full
            + " not in target containers: "
            + config["datahub_container_name"].lower()
        )
        return

    blob_client = blob_service_client.get_blob_client(container=blob_name_container, blob=blob_name_in_container)

    if not blob_client.exists():
        print(f"FSDH - blob Not foud: {blob_name_in_container} at {blob_url}")
        return

    clamav_socket = pyclamd.ClamdUnixSocket()

    scan_start_time = time.time()
    scan_result = scan_blob(blob_client, blob_name_full, clamav_socket)
    scan_time = time.time() - scan_start_time
    if scan_result:
        print(f"FSDH - Infected blob {blob_name_full}")

        try:
            # Create marker in infected container
            infected_blob_client = blob_service_client.get_blob_client(
                container=config["quarantine_container_name"],
                blob=blob_name_in_container,
            )

            if infected_blob_client.exists():
                print(f"FSDH - blob {blob_name_in_container} already exists in quarantine container, deleting")
                infected_blob_client.delete_blob()

            copy_time_start = time.time()
            if config["ENABLE_QUARANTINE"].lower() == "true":
                print(f"FSDH - copying blob {blob_name_in_container} to quarantine container ")
                infected_blob_client.start_copy_from_url(blob_client.url)
            copy_time = time.time() - copy_time_start

            print(f"FSDH - insert into storage table for {blob_name_in_container}")
            table_client = table_service_client.get_table_client(table_name="infectedfiles")

            try:
                entity = {
                    "PartitionKey": blob_name_in_container,
                    "RowKey": blob_client.get_blob_properties().last_modified,
                    "originalUrl": blob_client.url,
                    "quarrantineUrl": infected_blob_client.url,
                    "size_mb": round(blob_client.get_blob_properties().size / 1024 / 1024),
                    "threats": json.dumps(scan_result),
                    "scan_time_s": round(scan_time),
                    "copy_time_s": round(copy_time),
                }
                response = table_client.upsert_entity(entity)
                print(f"FSDH - insert into table for {blob_name_in_container} with response {response}")
            except Exception as e:  # pylint: disable=broad-exception-caught
                print(f"Error inserting to table: {e}")

        finally:
            blob_client.delete_blob()
    else:
        more_blob_metadata = {"avscan": "ok"}
        blob_metadata = blob_client.get_blob_properties().metadata
        blob_metadata.update(more_blob_metadata)
        blob_client.set_blob_metadata(metadata=blob_metadata)


def main():
    messages = queue_client.receive_messages(messages_per_page=10, visibility_timeout=14400)
    for msg_batch in messages.by_page():
        for msg in msg_batch:
            try:
                process_message(msg)
                queue_client.delete_message(msg)
            except Exception as e:  # pylint: disable=broad-exception-caught
                print(f"FSDH - Error processing message: {e}")


if __name__ == "__main__":
    main()
