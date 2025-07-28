#!/bin/bash
# Usage: update-dockerhub-readme.sh <readme-file> <dockerhub-username> <repo-name>
# Requires: DOCKERHUB_USERNAME and DOCKERHUB_TOKEN env vars (Docker Hub access token)
set -e

README_FILE="$1"
USERNAME="$2"
REPO="$3"

if [[ -z "$DOCKERHUB_USERNAME" || -z "$DOCKERHUB_TOKEN" ]]; then
  echo "DOCKERHUB_USERNAME and DOCKERHUB_TOKEN must be set in the environment." >&2
  exit 1
fi

if [[ ! -f "$README_FILE" ]]; then
  echo "README file $README_FILE not found!" >&2
  exit 1
fi

# Get README content
README_CONTENT=$(<"$README_FILE")

# Update Docker Hub repo description via API
# See: https://docs.docker.com/docker-hub/api/latest/

API_URL="https://hub.docker.com/v2/repositories/$USERNAME/$REPO/"

# Patch the full_description field
curl -sSL -X PATCH "$API_URL" \
  -H "Content-Type: application/json" \
  -u "$DOCKERHUB_USERNAME:$DOCKERHUB_TOKEN" \
  --data-binary @- <<EOF
{"full_description": $(jq -Rs . < "$README_FILE")}
EOF

echo "Docker Hub description updated."
