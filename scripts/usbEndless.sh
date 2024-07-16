#!/bin/bash
lsusb=$(lsusb | grep 0424:9514)
bus=$(echo $lsusb | awk '{print $2}')
dev=$(echo $lsusb | awk '{print $4}' | cut -c1-3)
while [ 1 -eq 1 ]
do
  echo switching off
  sudo /opt/iplon/scripts/hub-ctrl -b $bus -d $dev -P 2 -p 0 ; sleep 3; sudo /opt/iplon/scripts/hub-ctrl -b $bus -d $dev -P 2 -p 1
  echo switched back on
  sleep 10
done

