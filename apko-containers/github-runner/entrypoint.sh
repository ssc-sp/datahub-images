#!/bin/bash
# entrypoint.sh
set -e



# Check environment variables
[ -z "$JWT_TOKEN_FILEPATH" ] && { echo "Error: JWT_TOKEN_FILEPATH not set"; exit 1; }
[ -z "$GITHUB_APP_ID" ] && { echo "Error: GITHUB_APP_ID not set"; exit 1; }
[ -z "$ORG_NAME" ] && { echo "Error: ORG_NAME not set"; exit 1; }
[ -z "$GH_URL" ] && { echo "Error: GH_URL not set"; exit 1; }

[ -z "$GITHUB_RUNNER_GROUP" ] && echo "Warning: GITHUB_RUNNER_GROUP not set"
[ -z "$GITHUB_RUNNER_LABELS" ] && echo "Warning: GITHUB_RUNNER_LABELS not set"
[ -z "$ROOT_CA" ] && echo "Warning: ROOT_CA not set"

if [ -n "$ROOT_CA" ]; then
	echo "Installing custom root CA…"
    # Modified for standard Wolfi/Alpine paths
	cp /etc/ssl/certs/ca-certificates.crt /tmp/custom-root-ca.crt
	echo "$ROOT_CA" >>/tmp/custom-root-ca.crt
fi

jwt=$(<"$JWT_TOKEN_FILEPATH")

echo "Fetching installations for App ID $GITHUB_APP_ID..."
installations=$(curl -s -H "Authorization: Bearer $jwt" \
	-H "Accept: application/vnd.github+json" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/app/installations)

if [ -z "$installations" ] || [ "$installations" = "[]" ]; then
	echo "No installations found for this app. Please install the app first."
	exit 1
fi

installation_id=$(echo "$installations" | jq -r --arg org "$ORG_NAME" '.[] | select(.account.login == $org) | .id')
if [ -z "$installation_id" ] || [ "$installation_id" = "null" ]; then
	echo "Error: Could not find installation ID for org $ORG_NAME"
	exit 1
fi

echo "Found Installation ID: $installation_id"

echo "Requesting access token for Installation ID $installation_id..."
token=$(curl -s --request POST \
	--url "https://api.github.com/app/installations/$installation_id/access_tokens" \
	--header "Accept: application/vnd.github+json" \
	--header "X-GitHub-Api-Version: 2022-11-28" \
	--header "Authorization: Bearer $jwt" |
	jq -r '.token')

if [ -z "$token" ] || [ "$token" = "null" ]; then
	echo "Error: Failed to retrieve access token"
	exit 1
fi

echo "Requesting runner registration token for org $ORG_NAME..."
registration_token=$(curl -X POST -fsSL \
	-H 'Accept: application/vnd.github.v3+json' \
	-H "Authorization: Bearer $token" \
	-H 'X-GitHub-Api-Version: 2022-11-28' \
	"https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token" |
	jq -r '.token')

if [ -z "$registration_token" ] || [ "$registration_token" = "null" ]; then
	echo "Error: Failed to retrieve registration token"
	exit 1
fi

echo "Configuring runner..."
args=(--url "$GH_URL" --token "$registration_token" --unattended --ephemeral)

if [ -n "$GITHUB_RUNNER_GROUP" ]; then
	args+=(--runnergroup "$GITHUB_RUNNER_GROUP")
fi
if [ -n "$GITHUB_RUNNER_LABELS" ]; then
	args+=(--labels "$GITHUB_RUNNER_LABELS")
fi

if ! ./config.sh "${args[@]}"; then
	echo "Error: Failed to configure runner"
	exit 1
fi

echo "Starting runner..."
./run.sh

unset jwt