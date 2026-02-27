#!/bin/sh
set -eu

[ -z "${IDENTITY_ENDPOINT:-}" ] && {
	echo "Error: IDENTITY_ENDPOINT not set. Identity not exposed to container"
	exit 1
}
[ -z "${IDENTITY_HEADER:-}" ] && {
	echo "Error: IDENTITY_HEADER not set. Identity not exposed to container"
	exit 1
}
[ -z "${MANAGED_IDENTITY_OBJECT_ID:-}" ] && {
	echo "Error: MANAGED_IDENTITY_OBJECT_ID not set"
	exit 1
}
[ -z "${JWT_TOKEN_FILEPATH:-}" ] && {
	echo "Error: JWT_TOKEN_FILEPATH not set"
	exit 1
}
[ -z "${ROOT_CA:-}" ] && echo "Warning: ROOT_CA not set"

# Optional: import custom root CA from environment variable
if [ -n "$ROOT_CA" ]; then
	echo "Installing custom root CA…"
	cp /etc/ssl/certs/ca-certificates.crt /tmp/custom-root-ca.crt
	echo "$ROOT_CA" >>/tmp/custom-root-ca.crt
fi

JWT=$(curl -sS \
	-H "X-IDENTITY-HEADER: $IDENTITY_HEADER" \
	"${IDENTITY_ENDPOINT}?api-version=2019-08-01&resource=499b84ac-1321-427f-aa17-267ca6975798&object_id=${MANAGED_IDENTITY_OBJECT_ID}" |
	jq -r '.access_token')

if [ -z "$JWT" ] || [ "$JWT" = "null" ]; then
	echo "ERROR: Failed to retrieve jwt token from identity endpoint" >&2
	exit 1
fi

echo "$JWT" >"$JWT_TOKEN_FILEPATH"

if [ ! -s "$JWT_TOKEN_FILEPATH" ]; then
	echo "ERROR: JWT file '$JWT_TOKEN_FILEPATH' is missing or empty" >&2
	exit 1
fi

echo "JWT successfully written to $JWT_TOKEN_FILEPATH"

