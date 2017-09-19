#!/bin/bash

ver=$1
SCRIPT=$(realpath -s $0)
SCRIPTPATH=$(dirname $SCRIPT)

for SCRIPT in ${SCRIPTPATH}/${ver}-*
do
  if [ -f $SCRIPT -a -x $SCRIPT ]
  then
     source $SCRIPT
  fi
done

exit 0
