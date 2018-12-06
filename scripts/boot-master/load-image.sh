#!/bin/bash
LOGFILE=/tmp/loadimage.log
exec 1>>$LOGFILE 2> >(tee -a $LOGFILE >&2)

echo "Got the parameters $@"
# Defaults
source /tmp/icp-bootmaster-scripts/functions.sh
sourcedir=/opt/ibm/cluster/images
declare -a locations

# Parse options
while getopts ":l:i:s:u:p:" opt; do
  case $opt in
    l)
      locations+=${OPTARG}
      ;;
    u)
      username=${OPTARG}
      ;;
    p)
      password=${OPTARG}
      ;;
    i)
      image=${OPTARG}
      ;;
    s)
      echo "Will overwrite default sourcedir to ${OPTARG}"
      sourcedir=${OPTARG}
      ;;
    \?)
      echo "Invalid option : -$OPTARG in commmand $0 $*" >&2
      exit 1
      ;;
    :)
      echo "Missing option argument for -$OPTARG in command $0 $*" >&2
      exit 1
      ;;
  esac
done


# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${image}
echo "registry=${registry:-not specified} org=$org repo=$repo tag=$tag"

# Make sure sourcedir exists, in case we need to donwload some archives
mkdir -p ${sourcedir}

for image_location in ${locations[@]} ; do

  # Decide which protocol to use
  if [[ "${image_location:0:4}" == "http" ]]; then
    # Extract filename from URL if possible
    if [[ "${image_location: -2}" == "gz" ]]; then
      # Assume a sensible filename can be extracted from URL
      filename=$(basename ${image_location})
    else
      # TODO We'll need to attempt some magic to extract the filename
      echo "Not able to determine filename from URL ${image_location}" >&2
      exit 1
    fi

    # Download the image and set the image file name if we're on the same platform
    if [[ ${filename} =~ .*$(uname -m).* ]]; then
      # Download the file using auth if provided
      echo "Downloading ${image_url}" >&2
      wget --continue ${username:+--user} ${username} ${password:+--password} ${password} \
      -O ${sourcedir}/${filename} "${image_url}"

      echo "Setting image_file to ${sourcedir}/${filename}"
      image_file="${sourcedir}/${filename}"
    fi
  else
    # Assume NFS since this is the only other supported protocol
    # Separate out the filename and path
    nfs_mount=$(dirname ${image_location})
    image_file="${sourcedir}/$(basename ${image_location})"
    mkdir -p ${sourcedir}
    # Mount
    sudo mount.nfs $nfs_mount $sourcedir

  fi
done

if [[ -s "$image_file" ]]; then
  echo "Loading ${image_file} This can take a very long time." >&2
  tar xf ${image_file} -O | sudo docker load
else
  # If we don't have an image locally we'll pull from docker registry
  if [[ -z $(docker images -q ${registry}${registry:+/}${org}/${repo}:${tag}) ]]; then
    # If this is a private registry we may need to log in
    if [[ ! -z "$username" ]]; then
      docker login -u ${username} -p ${password} ${registry}
    fi
    # ${registry}${registry:+/} adds <registry>/ only if registry is specified
    docker pull ${registry}${registry:+/}${org}/${repo}:${tag}
  fi
fi
