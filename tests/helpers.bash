#!/usr/bin/env bash
################################
## Simple common helper
## functions for BATS tests
##
################################


#####################################
## Function to run a script in docker
## Inputs
##  -i <image>      Docker image to run scipt in, i.e. ubuntu:16.04
## -s <script>      Script to run
## -p <params>      Parameters to pass to script
## -t <command>     Command to run to validate script success. i.e. `ls /some/file/that/was/created`
## -f <cmd1:cmd2..> Colon separated list of commands to be faked. i.e. sudo if script uses sudo but container user is root
function run_in_docker() {
  local OPTIND o image script params validation_test
  while getopts ":i:s:p:t:f:" o; do
    case "${o}" in
      i)
        image=${OPTARG}
        ;;
      s)
        script=${OPTARG}
        ;;
      p)
        params="${OPTARG}"
        ;;
      t)
        validation_test="${OPTARG}"
        ;;
      f)
        fakes="${OPTARG}"
    esac
  done


  docker run -it -e APT_PREREQS="${APT_PREREQS}" -e YUM_PREREQS=${YUM_PREREQS} \
    -v ${SCRIPT_PATH}:/tmp/scripts -v ${TEST_DIR}:/tmp/tests \
    ${image} /tmp/tests/container-runtest.sh \
    -s ${script} -p "${params}" -t "${validation_test}" ${fakes:+-f} ${fakes}
  return $?
}

export -f run_in_docker
