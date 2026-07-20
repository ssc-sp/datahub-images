#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# entrypoint.sh
# Bootstrap an Azure Pipelines self‑hosted agent using
# AAD Managed Identity via Container Apps identity endpoint.
# Supports both dummy 'placeholder' agents and real one-shot agents,
# and cleans up by unregistering after run.
#
# Required environment variables:
#   AZP_URL                   e.g. https://dev.azure.com/MyOrg
#   AZP_POOL                  e.g. test-pool
#   MANAGED_IDENTITY_OBJECT_ID  Managed Identity Object ID
# Optional environment variables:
#   AZP_AGENT_NAME            Agent name (defaults to hostname)
#   AZP_AGENT_VERSION         Agent version (defaults to 4.255.0)
#   AZP_WORK                  Agent working directory (defaults to _work)
#   ROOT_CA                   Custom root certificate (PEM format)
# ----------------------------------------------------------------------------
# Trap for the cleanup confuses the lintor, disabling lint check
# shellcheck disable=SC2317
set -euo pipefail

# helper functions
log() { echo "--> $*"; }
error() {
	echo "ERROR: $*" >&2
	exit 1
}
cleanup() {
	log "Unregistering agent '$AZP_AGENT_NAME' from pool '$AZP_POOL'"
	cd "$WORKDIR"
	./config.sh remove --unattended --auth pat --token "$JWT"
	rm -rf "$WORKDIR"
}

# ----- Sanity checks -----
for cmd in curl jq tar apt-cache apt-get update-ca-certificates; do
	command -v "$cmd" >/dev/null 2>&1 || error "$cmd not found"
done

[ -z "${IDENTITY_ENDPOINT:-}" ] && error "IDENTITY_ENDPOINT not set"
[ -z "${IDENTITY_HEADER:-}" ] && error "IDENTITY_HEADER not set"
[ -z "${MANAGED_IDENTITY_OBJECT_ID:-}" ] && error "MANAGED_IDENTITY_OBJECT_ID not set"
[ -z "${AZP_URL:-}" ] && error "AZP_URL not set"
[ -z "${AZP_POOL:-}" ] && error "AZP_POOL not set"

# ----- Import custom root CA -----
if [ -n "${ROOT_CA:-}" ]; then
	log "Installing custom root CA"
	cp /etc/ssl/certs/ca-certificates.crt /tmp/custom-root-ca.crt
	echo "$ROOT_CA" >>/tmp/custom-root-ca.crt
	log "Custom RootCA set to /tmp/custom-root-ca.crt "
fi

# ----- Configuration -----
AZP_AGENT_VERSION="${AZP_AGENT_VERSION:-5.275.0}"
AZP_AGENT_URL="https://download.agent.dev.azure.com/agent/${AZP_AGENT_VERSION}/vsts-agent-linux-x64-${AZP_AGENT_VERSION}.tar.gz"
WORKDIR="$(mktemp -d)"
AZP_WORK="${AZP_WORK:-_work}"
AZP_AGENT_NAME="${AZP_AGENT_NAME:-$(hostname)}"

# ----- Download and unpack agent -----
log "Downloading and extracting Azure Pipelines agent v${AZP_AGENT_VERSION}"
mkdir -p "$WORKDIR"
curl -fsSL "$AZP_AGENT_URL" | tar xzf - --strip-components=1 -C "$WORKDIR"
cd "$WORKDIR"

# ----- Acquire Azure DevOps token -----
log "Fetching Azure DevOps access token via identity endpoint"
JWT=$(curl -sS \
	-H "X-IDENTITY-HEADER: $IDENTITY_HEADER" \
	"${IDENTITY_ENDPOINT}?api-version=2019-08-01&resource=499b84ac-1321-427f-aa17-267ca6975798&object_id=${MANAGED_IDENTITY_OBJECT_ID}" |
	jq -r '.access_token')

[ -z "$JWT" ] || [[ "$JWT" == "null" ]] && error "Failed to retrieve access_token"

# ----- Configure the agent -----
log "Configuring agent '$AZP_AGENT_NAME' on pool '$AZP_POOL' @ '$AZP_URL'"
bash config.sh --unattended \
	--agent "$AZP_AGENT_NAME" \
	--url "$AZP_URL" \
	--pool "$AZP_POOL" \
	--auth pat \
	--token "$JWT" \
	--work "$AZP_WORK" \
	--acceptTeeEula \
	--replace

# ----- Dummy agent logic -----
if grep -qi placeholder <<<"$AZP_AGENT_NAME"; then
	log "Placeholder agent registered; exiting immediately"
	exit 0
fi

# Set trap for running cleanup actions
trap cleanup EXIT INT TERM

# ----- Run agent once -----
log "Starting agent in one-shot mode"
./run.sh --once
EXIT_CODE=$?

# ----- Exit handling -----
if [ "$EXIT_CODE" -eq 0 ]; then
	log "Agent completed job successfully"
else
	error "Agent failed with exit code $EXIT_CODE"
fi
exit $EXIT_CODE
