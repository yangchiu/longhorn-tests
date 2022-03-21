#!/bin/bash

if [[ $@ =~ "--junitxml=" ]] ; then
  pytest -v "$@"
else 
  set -x
  
  flake8

  pytest -v "$@"
fi 
