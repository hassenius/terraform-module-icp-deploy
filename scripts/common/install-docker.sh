#!/bin/bash
LOGFILE=/tmp/install-docker.log
exec &> >(tee -a "$LOGFILE")

echo "Got first parameter $1"
package_location=$1
sourcedir=/tmp/icp-docker

if docker --version &>/dev/null
then
  echo "Docker already installed. Exiting"
  exit 0
fi

# Figure out if we're asked to install from provided
if [[ -z ${package_location} ]]
then
  echo "Not required to install ICP provided docker."
else

  mkdir -p ${sourcedir}

  # Decide which protocol to use
  if [[ "${package_location:0:3}" == "nfs" ]]
  then
    # Separate out the filename and path
    nfs_mount=$(dirname ${package_location:4})
    package_file="${sourcedir}/$(basename ${package_location})"
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
  sudo ${package_file} --install

  exit 0
fi

# If we're here, we probably want to install docker from relevant repos acording to best practices
#Find Linux Distro
if grep -q -i ubuntu /etc/*release
  then
    OSLEVEL=ubuntu
  else
    OSLEVEL=other
fi
echo "Operating System is $OSLEVEL"

ubuntu_install() {
  # Install according to https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-docker-ce
  #   and https://docs.docker.com/storage/storagedriver/select-storage-driver/

  # This will install docker using overlay2 storage driver. This is a file based storage driver and good all around choice.

    # Download the docker prereqs
    sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common

    # Download the docker GPG keys
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Add docker repo
    sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"

     # Install
     sudo apt-get update
     sudo apt-get install -y docker-ce

     # Ensure docker starts at boot time
     sudo systemctl enable docker
     sudo systemctl start docker
}

crlinux_install() {
  # On centos and RHEL we need to setup docker with devicemapper and direct-lvm
  # loopback-lvm is really only appropriate for testing, not performant.
  echo "####################### PLEASE NOTE #########################"
  echo "Docker setup on RHEL and CentOS currently not performed."
  echo "It's recommended you setup docker with devicemapper and "
  echo "direct-lvm in production environments"
  echo "#############################################################"
}

if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

echo "Complete.."
exit 0
