#!/bin/bash
LOGFILE=/tmp/loadimage.log
exec  > $LOGFILE 2>&1

echo "Got first parameter $1"
echo "Second parameter $2"

source /tmp/icp-bootmaster-scripts/functions.sh


# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}
echo "org=$org repo=$repo tag=$tag"

if [[ -s "$2" ]]
then
  tar xf ${2} -O | sudo docker load
else
  # If we don't have an image file locally we'll pull from docker hub registry
  docker pull ${org}/${repo}:${tag}
fi



