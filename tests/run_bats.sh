#!/usr/bin/env bash
test_file=$1

if [[ -z "${test_file}" ]]; then
  echo "Usage: $0 <bats_file | all>"
  exit 1
fi

export SCRIPT_PATH="$(pwd | sed 's/tests/scripts/g')"
export TEST_DIR="$(pwd)"
# Build a test matrix

# Operating systems and versions that should be suppported
images=("ubuntu:16.04" "centos:centos7.6.1810")

if [[ "${test_file}" == "all" ]] ; then
  bats_files=(./*.bats)
else
  bats_files=($test_file)
fi

for bats_file in ${bats_files[@]}; do
  echo "=> $bats_file"

  for image in ${images[@]} ; do
    echo "==> $image"
    export IMAGE=${image}
    bats "$bats_file"
  done
done
