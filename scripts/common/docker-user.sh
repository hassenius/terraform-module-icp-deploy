#!/bin/bash

iam=$(whoami)

if [[ $iam != "root" ]]
then
  sudo usermod -a -G docker $iam
fi
