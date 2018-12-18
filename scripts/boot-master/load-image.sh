#!/bin/bash
LOGFILE=/tmp/loadimage.log
exec 3>&1
exec > >(tee -a ${LOGFILE} >/dev/null) 2> >(tee -a ${LOGFILE} >&3)

while getopts ":v:l:" arg; do
    case "${arg}" in
      v)
        image=${OPTARG}
        ;;
      l)
        image_location=${OPTARG}
        ;;
    esac
done

sourcedir=/opt/ibm/cluster/images

source /tmp/icp-bootmaster-scripts/functions.sh

if [[ ! -z ${image} ]]; then
  # Figure out the version
  # This will populate $org $repo and $tag
  parse_icpversion ${image}
  echo "registry=${registry:-not specified} org=$org repo=$repo tag=$tag"
fi

if [[ "${image_location}" != "false" ]]
then
  # Decide which protocol to use
  if [[ "${image_location:0:3}" == "nfs" ]]
  then
    # Separate out the filename and path
    nfs_mount=$(dirname ${image_location:4})
    image_file="${sourcedir}/$(basename ${image_location})"
    mkdir -p ${sourcedir}
    # Mount
    sudo mount.nfs $nfs_mount $sourcedir
  elif [[ "${image_location:0:4}" == "http" ]]
  then
    # Figure out what we should name the file
    filename="ibm-cloud-private-x86_64-${tag%-ee}.tar.gz"
    mkdir -p ${sourcedir}
    # Figure out if we need auth
    if [[ ${image_location} =~ http:.*:.*@http.* ]]
    then
      # Save the auth section and extract username password
      auth=${image_location%%@http*}
      userpass=${auth#http:}
      htuser=${userpass%%:*}
      htpass=${userpass#*:}

      image_url=${image_location##*@}
    else
      image_url=${image_location#http:}
    fi

    # Download the file using auth if provided
    wget --continue ${htuser:+--user} ${htuser} ${htpass:+--password} ${htpass} \
     -O ${sourcedir}/${filename} "${image_url}"

    # Set the image file name
    image_file="${sourcedir}/${filename}"
  fi
fi

if [[ -s "$image_file" ]]
then
  echo "Loading image file ${image_file}. This can take a very long time" >&2
  # If we have pv installed, we can use that for improved reporting
  if which pv >>/dev/null; then
    pv --interval 30 ${image_file} | tar zxf - -O | sudo docker load >&2
  else
    tar xf ${image_file} -O | sudo docker load
  fi
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
