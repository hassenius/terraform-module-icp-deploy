#!/bin/bash
LOGFILE=/tmp/install-docker.log
exec  > $LOGFILE 2>&1

echo "Got first parameter $1"
package_location=$1
sourcedir=/tmp/icp-docker

# Figure out if we're asked to install at all
if [[ -z ${package_location} ]]
then
  echo "Not required to install ICP provided docker. Exiting"
  exit 0
fi

if docker --version
then
  echo "Docker already installed. Exiting"
fi

mkdir -p ${sourcedir}

# Decide which protocol to use
if [[ "${package_location:0:3}" == "nfs" ]]
then
  # Separate out the filename and path
  nfs_mount=$(dirname ${image_location:4})
  package_file="${sourcedir}/$(basename ${image_location})"
  # Mount 
  sudo mount.nfs $nfs_mount $sourcedir
elif [[ "${package_location:0:4}" == "http" ]]
then
  # Figure out what we should name the file
  filename="icp-docker.bin"
  mkdir -p ${sourcedir}
  curl -o ${sourcedir}/${filename} "${package_location#http:}"
  package_file="${sourcedir}/${filename}"
fi

chmod a+x ${package_file}
sudo ${package_file}

# Make sure our user is added to the docker group if needed
/tmp/icp-common-scripts/docker-user.sh
