#!/bin/bash

if [ $(whoami) != "root" ]
then
  echo this scripts needs to be run as user root!
  exit
fi

if [ -z $1 ]
then
  echo please enter device \(ppp0\)
  exit
elif [ -z $2 ]
then
  echo please enter start time \(09:15\)
  exit
elif [ -z $3 ]
then
  echo please enter end time \(10:30\)
  exit
fi
echo waiting 60 seconds for checking start hour
sleep 60 
echo waiting for starting
while [ "$(date +%H:%M)" != "$2" ]
do
  sleep 10
done
echo starting tcpdump
tcpdump -i $1 -w /var/log/tcpdump-$(date +%s).log &
tcpdumppid=$!
sleep 10
echo waiting for ending
while [ "$(date +%H:%M)" != "$3" ]
do
  sleep 10
done
echo killing tcpdump
kill $tcpdumppid
