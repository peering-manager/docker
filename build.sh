#!/bin/bash

URL="https://github.com/respawner/peering-manager.git"
PEERING_MANAGER_PATH="peering-manager"

echo "▶️ $0 $*"

set -e

echo "👓 Going in the right location"
cd $(dirname $(realpath $0))
echo "✅ We are there"

echo "🌀 Cleaning up remains of last build"
rm -rf ${PEERING_MANAGER_PATH}
echo "✅ All cleaned"

echo "🌐 Checking out 'master' of Peering Manager from '${URL}' into '${PEERING_MANAGER_PATH}'"
git clone ${URL} ${peering_manager_directory}
echo "✅ Checked out Peering Manager"

echo "🐳 Building Docker image"
docker build -t peering-manager --build-arg PEERING_MANAGER_PATH=./${PEERING_MANAGER_PATH} .
echo "✅ Docker image ready"
