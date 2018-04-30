#!/bin/bash
#This script updates hosts with required prereqs
#if [ $# -lt 1 ]; then
#  echo "Usage $0 <hostname>"
#  exit 1
#fi

#HOSTNAME=$1

LOGFILE=/tmp/prereqs.log
exec > $LOGFILE 2>&1

#Find Linux Distro
if grep -q -i ubuntu /etc/*release
  then
    OSLEVEL=ubuntu
  else
    OSLEVEL=other
fi
echo "Operating System is $OSLEVEL"

ubuntu_install(){
  packages_to_check="\
python-yaml \
thin-provisioning-tools \
lvm2 \
libltdl7"

  sudo sysctl -w vm.max_map_count=262144
  sudo apt-get -y update
  sudo apt-get install -y apt-transport-https nfs-common ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

  ## Attempt to avoid probelems when dpkg requires configuration
  export DEBIAN_FRONTEND=noninteractive
  export DEBIAN_PRIORITY=critical
  sudo -E apt-get -y update
  sudo -E apt-get -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade

  sudo apt-get install -y python unzip moreutils python-pip
  sudo service iptables stop
  sudo ufw disable
  sudo apt-get install -y docker-ce
  sudo service docker start
  echo y | pip uninstall docker-py
}
crlinux_install(){
  packages_to_check="\
PyYAML \
device-mapper \
libseccomp \
libtool-ltdl \
libcgroup \
iptables \
device-mapper-persistent-data \
lvm2"

  for package in ${packages_to_check}; do
    if ! rpm -q ${package} &> /dev/null; then
      packages_to_install="${packages_to_install} ${package}"
    fi
  done

}

if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

echo "Complete.."
exit 0
