#!/bin/bash
LOGFILE=/tmp/loadimage.log
exec  > $LOGFILE 2>&1

echo "Got first parameter $1"
echo "Second parameter $2"
echo "Third parameter $3"
image=$1
image_file=$2
image_location=$3
sourcedir=/tmp/icpsource

source /tmp/icp-bootmaster-scripts/functions.sh


# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${image}
echo "org=$org repo=$repo tag=$tag"

if [[ "${image_location}" != "false" ]]
then
  # Decide which protocol to use
  if [[ "${image_location:0:3}" == "nfs" ]]
  then
    # Separate out the filename and path
    nfs_mount=$(dirname ${image_location:4})
    image_file="${sourcedir}/$(basename ${image_location})"
    mkdir -p ${sourcedir}
    sudo mount.nfs $nfs_mount $sourcedir
  fi
fi

if [[ -s "$image_file" ]]
then
  tar xf ${image_file} -O | sudo docker load
else
  # If we don't have an image file locally we'll pull from docker hub registry
  docker pull ${org}/${repo}:${tag}
fi



