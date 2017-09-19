#!/bin/bash

LOGFILE=/tmp/loadimage.log
exec  > $LOGFILE 2>&1

# ${1} = version
# ${2} = image file

echo "Got first parameter $1"
echo "Second parameter $2"

if [[ -s "$2" ]]
then
  tar xf ${2} -O | sudo docker load
else
  # If we don't have an image file locally we'll pull from docker hub registry
  docker pull ibmcom/cfc-installer:${1}
fi



