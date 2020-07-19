#!/bin/sh 
cd $(dirname $(realpath $0))

pm_dir="peering-manager"
rm -rf ${pm_dir}
git clone https://github.com/respawner/peering-manager.git ${pm_dir}
docker build -t peering-manager .
