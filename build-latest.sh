#!/bin/bash
# Builds the latest released version

echo "▶️ $0 $*"

# Check for the jq library needed for parsing JSON
if ! command -v jq; then
  echo "⚠️  jq command missing from \$PATH!"
  exit 1
fi

# Querying GitHub to get the latest version
SRC_ORG="${SRC_ORG-peering-manager}"
SRC_REPO="${SRC_REPO-peering-manager}"
GITHUB_REPO="${SRC_ORG}/${SRC_REPO}"
URL_RELEASES="https://api.github.com/repos/${GITHUB_REPO}/releases"

# Composing the JQ command to extract the most recent version number
JQ_LATEST="sort_by(.published_at) | reverse | .[0] | select(.prerelease==false) | .tag_name"

# Querying the Github API to fetch the most recent version number
VERSION=$(curl -sS "${URL_RELEASES}" | jq -r "${JQ_LATEST}")

./build.sh "${VERSION}" $@
exit $?
