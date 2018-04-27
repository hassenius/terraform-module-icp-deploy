#!/bin/bash
LOGFILE=/tmp/generate_hostsfiles.log
exec  > $LOGFILE 2>&1
WORKDIR=/opt/ibm/cluster
ICPDIR=$WORKDIR

# Make sure ssh key has correct permissions set before using
chmod 600 ${WORKDIR}/ssh_key

# Global array variable for holding all cluster ip/hostnames
declare -A cluster

# Make sure /tmp/hosts is empty, in case we running this a second time
[[ -e /tmp/hosts ]] && rm /tmp/hosts

# Functions for "traditional" groups (master, proxy, worker, management)
read_from_groupfiles() {
  ## First compile a list of all nodes in the cluster with ip addresses and associated hostnames
  declare -a master_ips
  IFS=', ' read -r -a master_ips <<< $(cat ${WORKDIR}/masterlist.txt)

  declare -a worker_ips
  IFS=', ' read -r -a worker_ips <<< $(cat ${WORKDIR}/workerlist.txt)

  declare -a proxy_ips
  IFS=', ' read -r -a proxy_ips <<< $(cat ${WORKDIR}/proxylist.txt)

  ## First gather all the hostnames and link them with ip addresses
  declare -A workers
  for worker in "${worker_ips[@]}"; do
    workers[$worker]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${worker} hostname)
    cluster[$worker]=${workers[$worker]}
    printf "%s     %s\n" "$worker" "${cluster[$worker]}" >> /tmp/hosts
  done

  declare -A proxies
  for proxy in "${proxy_ips[@]}"; do
    proxies[$proxy]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${proxy} hostname)
    cluster[$proxy]=${proxies[$proxy]}
    printf "%s     %s\n" "$proxy" "${cluster[$proxy]}" >> /tmp/hosts
  done

  declare -A masters
  for m in "${master_ips[@]}"; do
    # No need to ssh to self
    if [[ "$m" == "${master_ips[0]}" ]]
    then
      masters[$m]=$(hostname)
    else
      masters[$m]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${m} hostname)
    fi
    cluster[$m]=${masters[$m]}
    printf "%s     %s\n" "$m" "${cluster[$m]}" >> /tmp/hosts
  done

  # Add management nodes if separate from master nodes
  if [[ -s ${WORKDIR}/managementlist.txt ]]
  then
    declare -a management_ips
    IFS=', ' read -r -a management_ips <<< $(cat ${WORKDIR}/managementlist.txt)

    declare -A mngrs
    for m in "${management_ips[@]}"; do
      mngrs[$m]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${m} hostname)
      cluster[$m]=${mngrs[$m]}
      printf "%s     %s\n" "$m" "${cluster[$m]}" >> /tmp/hosts
    done
  fi

  ## Generate the hosts file for the ICP installation
  echo '[master]' > ${ICPDIR}/hosts
  for master in "${master_ips[@]}"; do
    echo $master >> ${ICPDIR}/hosts
  done

  echo  >> ${ICPDIR}/hosts
  echo '[worker]' >> ${ICPDIR}/hosts
  for worker in "${worker_ips[@]}"; do
    echo $worker >> ${ICPDIR}/hosts
  done

  echo  >> ${ICPDIR}/hosts
  echo '[proxy]' >> ${ICPDIR}/hosts
  for proxy in "${proxy_ips[@]}"; do
    echo $proxy >> ${ICPDIR}/hosts
  done

  # Add management host entries if separate from master nodes
  if [[ ! -z ${management_ips} ]]
  then
    echo  >> ${ICPDIR}/hosts
    echo '[management]' >> ${ICPDIR}/hosts
    for m in "${management_ips[@]}"; do
      echo $m >> ${ICPDIR}/hosts
    done
  fi
}


read_from_hostgroups() {
  # First parse the hostgroup json
  python /tmp/icp-bootmaster-scripts/parse-hostgroups.py

  # Get the cluster ips
  declare -a cluster_ips
  IFS=',' read -r -a cluster_ips <<< $(cat /tmp/cluster-ips.txt)

  # Generate the hostname/ip combination
  for node in "${cluster_ips[@]}"; do
    cluster[$node]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${node} hostname)
    printf "%s     %s\n" "$node" "${cluster[$node]}" >> /tmp/hosts
  done


}

#TODO: Figure out the situation when using separate boot node
#TODO: Make sure /tmp/hosts is empty, so we don't double up all the time
update_etchosts() {
  ## Update all hostfiles in all nodes in the cluster
  for node in "${!cluster[@]}"; do
    # No need to ssh to self
    if [[ "$node" == "${master_ips[0]}" ]]
    then
      cat /tmp/hosts | cat - /etc/hosts | sudo tee /etc/hosts
    else
      cat /tmp/hosts | ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${node} 'cat - /etc/hosts | sudo tee /etc/hosts'
    fi
  done
}

# if icp-hosts-groups.json is there it will be populated by '{}' if not using hostgroups
# Let group files take preference
if [[ -s ${WORKDIR}/masterlist.txt ]]; then
  read_from_groupfiles
elif [[ -s /tmp/icp-host-groups.json ]]; then
  read_from_hostgroups
else
  echo "Couldn't find any hosts"
  exit 1
fi

update_etchosts
