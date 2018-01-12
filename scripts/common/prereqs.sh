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
  #Update hostname
#  hostnamectl set-hostname $HOSTNAME
  #install epel
  cd /tmp
  sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E '%{rhel}').noarch.rpm
  sudo yum clean all
  sudo yum repolist
  #Install net-tools
  sudo yum -y install net-tools
  sudo sysctl -w vm.max_map_count=262144
  sudo systemctl disable firewalld
  sudo systemctl stop firewalld
  sudo yum -y install unzip moreutils ntp python-pip python-setuptools nfs-utils wget
  #add docker repo and install
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2

}

if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

echo "Complete.."
exit 0
