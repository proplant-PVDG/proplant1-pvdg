#!/bin/bash
if [ -e /var/run/usbreset.lock ]
then
  echo script already running!
  exit 0
else
  touch /var/run/usbreset.lock
fi
if [ -e /tmp/usbreset ]
then
  TS=$(cat /tmp/usbreset)
else
  TS=0
fi
DIFF=$(($(date +%s) - $TS))
TIMESPAN=20
TIMEIP=120
if [ $DIFF -gt $TIMESPAN ]
then
  echo reseting usb!
  lsusb=$(lsusb | grep 0424:9514)
  bus=$(echo $lsusb | awk '{print $2}')
  dev=$(echo $lsusb | awk '{print $4}' | cut -c1-3)
  sudo /opt/iplon/scripts/hub-ctrl -b $bus -d $dev -P 2 -p 0 ; sleep 3; sudo /opt/iplon/scripts/hub-ctrl -b $bus -d $dev -P 2 -p 1
  date +%s > /tmp/usbreset
  HASIP=$(ip addr show | grep -ci 169.254)
  if [ $HASIP -eq 0 ]
  then
    sleep 10
    FT=$(date +%s)
    while [ $HASIP -eq 0 ]
    do
      echo restarting network!
      sudo /etc/init.d/networking restart
      sleep 10
      DIFF=$(($(date +%s) - $FT))
      if [ $DIFF -gt $TIMEIP ]
      then
        HASIP=1
        echo exiting, but got no ip address in range 169.254 after $TIMEIP seconds!
      else
        HASIP=$(ip addr show | grep -ci 169.254)
      fi
    done
  fi
else
  echo script already runs the last $TIMESPAN seconds!
fi
rm /var/run/usbreset.lock

