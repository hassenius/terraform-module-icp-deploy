#!/bin/bash
source /tmp/icp-bootmaster-scripts/functions.sh

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}
echo "registry=${registry:-not specified} org=$org repo=$repo tag=$tag"

docker run -e LICENSE=accept -e ANSIBLE_CALLBACK_WHITELIST=profile_tasks,timer --net=host -t -v /opt/ibm/cluster:/installer/cluster ${registry}${registry:+/}${org}/${repo}:${tag} install -vv | tee /tmp/icp-install-log.txt
