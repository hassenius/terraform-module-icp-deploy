#!/bin/bash
LOGFILE=/tmp/copyclusterskel.log
exec  > $LOGFILE 2>&1

echo "Got first parameter $1"


source /tmp/icp-bootmaster-scripts/functions.sh

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}
echo "registry=${registry:-not specified} org=$org repo=$repo tag=$tag"

# Ensure that /opt/ibm is present and copy default data directory
sudo mkdir -p /opt/ibm
sudo chown $(whoami):$(whoami) -R /opt/ibm
docker run -e LICENSE=accept -v /opt/ibm:/data ${registry}${registry:+/}${org}/${repo}:${tag} cp -r cluster /data

# Take a backup of original config file, to keep a record of original settings and comments
cp /opt/ibm/cluster/config.yaml /opt/ibm/cluster/config.yaml-original
