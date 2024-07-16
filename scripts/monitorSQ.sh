#!/bin/bash

while [ 1 -eq 1 ]
do
  wvdial sq 2>&1 | grep CSQ:
  sleep 1
done

