# pylint: disable=missing-module-docstring
# pylint: disable=missing-function-docstring
# pylint: disable=import-error

import base64
import json
import os
import tempfile
from datetime import datetime

import pyclamd
from azure.data.tables import TableServiceClient
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from azure.storage.queue import QueueClient

CHUNK_SIZE = 1024 * 1024 * 1024 * 1


def get_config():
    return {
        "STORAGE_ACCOUNT": os.getenv("STORAGE_ACCOUNT"),
        "CLIENT_ID": os.getenv("CLIENT_ID"),
        "queue_name": os.getenv("queue_name") or "virus-scan",
        "result_queue_name": os.getenv("result_queue_name") or "clamav-scan-result",
        "quarantine_container_name": os.getenv("quarantine_container_name") or "datahub-quarantine",
        "datahub_container_name": os.getenv("container_name") or "datahub",
        "WORK_DIR": os.getenv("WORK_DIR") or "/datahub-temp",
        "ENABLE_QUARANTINE": os.getenv("ENABLE_QUARANTINE") or "false",
    }


config = get_config()
credential = DefaultAzureCredential(managed_identity_client_id=config["CLIENT_ID"])

queue_client = QueueClient(
    account_url="https://" + config["STORAGE_ACCOUNT"] + ".queue.core.windows.net/",
    queue_name=config["queue_name"],
    credential=credential,
)

result_queue_client = QueueClient(
    account_url="https://" + config["STORAGE_ACCOUNT"] + ".queue.core.windows.net/",
    queue_name=config["result_queue_name"],
    credential=credential,
)

blob_service_client = BlobServiceClient(
    account_url="https://" + config["STORAGE_ACCOUNT"] + ".blob.core.windows.net/", credential=credential
)

table_service_client = TableServiceClient(
    endpoint="https://" + config["STORAGE_ACCOUNT"] + ".table.core.windows.net/", credential=credential
)


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

            if threat_found > 0:
                print(f"FSDH - Infected blob chunk {chunk_index}: {blob_full_name}")
                break

            if "clamavtest2025a" in blob_full_name:
                threats.append("Testing...file name include clamavtest2025a")
                break

            print(f"FSDH - blob chunk {chunk_index} is clean: {blob_full_name}")

        chunk_start += CHUNK_SIZE
        chunk_index += 1

    return threats


def split_blob_path(blob_name_full: str) -> tuple[str, str, str, str]:
    parts = blob_name_full.strip("/").split("/")
    container = parts[3]
    blob_in_container = "/".join(parts[5:])
    return container, blob_in_container, "/" + container + "/" + blob_in_container, blob_name_full


def process_message(message):
    json_data = json.loads(base64.b64decode(message.content))
    blob_name_container, blob_name_in_container, blob_name_with_container, blob_name_full = split_blob_path(
        json_data["subject"]
    )
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

    scan_start_time = datetime.now()
    scan_result = scan_blob(blob_client, blob_name_full, clamav_socket)
    scan_end_time = datetime.now()
    more_blob_metadata = {"avscan": "ok"}

    if scan_result:
        print(f"FSDH - Infected blob {blob_name_full}")

        try:
            # Create marker in infected container
            infected_blob_client = blob_service_client.get_blob_client(
                container=config["quarantine_container_name"],
                blob=blob_name_container + "/" + blob_name_in_container,
            )

            if infected_blob_client.exists():
                print(f"FSDH - blob {blob_name_in_container} already exists in quarantine container, deleting")
                infected_blob_client.delete_blob()

            if config["ENABLE_QUARANTINE"].lower() == "true":
                print(f"FSDH - copying blob {blob_name_in_container} to quarantine container ")
                infected_blob_client.start_copy_from_url(blob_client.url)

            print(f"FSDH - insert into storage table for {blob_name_in_container}")
            table_client = table_service_client.get_table_client(table_name="infectedfiles")

            try:
                entity = {
                    "PartitionKey": blob_name_with_container.replace("/", "|||"),
                    "RowKey": datetime.now().isoformat() + "Z",
                    "fileName": blob_name_with_container,
                    "threats": json.dumps(scan_result),
                }
                print("FSDH - inserting into table")
                table_client.create_entity(entity=entity)
            except Exception as e:  # pylint: disable=broad-exception-caught
                print(f"Error inserting to table: {e}")
                raise

        finally:
            more_blob_metadata = {"avscan": "fail", "avscan_reason": json.dumps(scan_result)}
            if config["ENABLE_QUARANTINE"].lower() == "true":
                blob_client.delete_blob()

    blob_metadata = blob_client.get_blob_properties().metadata
    # Read metadata so we can emit the original values in the result message.
    blob_metadata.update(more_blob_metadata)
    blob_client.set_blob_metadata(metadata=blob_metadata)

    result_queue_client.send_message(
        json.dumps(
            {
                "ScanStartTime": scan_start_time.isoformat(),
                "ScanEndTime": scan_end_time.isoformat(),
                "ScanError": json.dumps(scan_result) if scan_result else "",
                "ScannedFile": blob_url,
                "OriginalBlobMetadata": dict(blob_metadata or {}),
            }
        )
    )


def main():
    messages = queue_client.receive_messages(messages_per_page=10, visibility_timeout=14400)
    for msg_batch in messages.by_page():
        for msg in msg_batch:
            try:
                process_message(msg)
                queue_client.delete_message(msg)
            except Exception as e:  # pylint: disable=broad-exception-caught
                print(f"FSDH - Error processing message: {e}")
                queue_client.update_message(message=msg, visibility_timeout=3600 * 8)


if __name__ == "__main__":
    main()
