#!/bin/bash
#####################################
## Script to run a script inside a docker container
##
## Will install any package in YUM_PREREQS or APT_PREREQS environment variables
## prior to running any other script
##
## Inputs
## -s <script>      Script to run
## -p <params>      Parameters to pass to script
## -t <command>     Command to run to validate script success. i.e. `ls /some/file/that/was/created`
## -f <cmd1:cmd2..> Colon separated list of commands to be faked so they exist
##                    but actual application is not installed.
##                    i.e. sudo if script uses sudo but container user is root.
####################################
echo "Got parameters $@"

while getopts ":s:p:t:f:" o; do
  case "${o}" in
    s)
      script=${OPTARG}
      ;;
    p)
      params=($(echo ${OPTARG}))
      ;;
    t)
      validation_test="${OPTARG}"
      ;;
    f)
      fake="${OPTARG}"
      echo "Got fake $fake"
      ;;
  esac
done

# Here we probably need to ensure that prereqs are installed in the container
function install_prepreqs() {
  if [[ -f /etc/redhat-release  ]]; then
     IFS=":" read -a packages <<< $YUM_PREREQS
     echo "Installing test prereqs ${packages[@]}"
     yum install -y -q ${packages[@]}
  else
    IFS=":" read -a packages <<< $APT_PREREQS
    echo "Installing test prereqs ${packages[@]}"
    apt-get update &>/dev/null && \
    apt-get install -y ${packages[@]}
  fi
}

function setup_script_path() {
  cd /tmp
  cp -r /tmp/scripts/common /tmp/icp-common-scripts
  cp -r /tmp/scripts/boot-master /tmp/icp-bootmaster-scripts
  chmod a+x /tmp/icp-common-scripts/*
  chmod a+x /tmp/icp-bootmaster-scripts/*
}

function docker() {
  # This is a simple function to fake docker.
  # If needed we can implement fake image list and things to emulate

  return 0
}

function tar() {
  # This is a simple function to fake tar.

  return 0
}

function sudo() {
  # We'll just forward the calls, the return code will also be returned back
  $@
}

install_prepreqs
setup_script_path

echo "Fake is $fake"
if [[ ! -z $fake ]]; then
  IFS=":" read -a cmds <<< $fake
  for cmd in ${cmds[@]}; do
    echo "Creating fake function for $cmd"
    export -f $cmd
  done
fi

# Call the script, with the necessary parameters
echo "Callings script $script with params ${params[@]}"
$script ${params[@]}
sc=$?
echo "${script} exit code $sc"

tc=0
if [[ ! -z ${validation_test} ]]; then
  echo "Running validation test ${validation_test}"
  ${validation_test}
  tc=$?
  echo "Validation exit code $tc"
fi

# This will exit success if BOTH script and validation test succeeds
exit $(($sc+$tc))
