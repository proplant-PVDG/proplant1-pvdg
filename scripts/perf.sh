#!/bin/bash

MAX=0
MIN=99999
SUM=0
I=1

while [ $I -le $2 ]
do
  RES=$((time $1) 2>&1 | grep real)
  #echo $RES
  MINUTES=$(echo $RES | awk '{print $2}')
  MINUTES=${MINUTES%m*}
  HSECS=$(echo $RES | awk '{print $2}')
  HSECS=${HSECS#*m}
  SECS=${HSECS%.*}
  HSECS=${HSECS#*.}
  HSECS=${HSECS%*s}
  HSECS=${HSECS#0*}
  RES=$(($HSECS+$(($MINUTES*6000))+$(($SECS*100))))
  #echo $RES
  SUM=$(($SUM+$RES))
  if [ $RES -gt $MAX ]
  then
    MAX=$RES
  fi
  if [ $RES -lt $MIN ]
  then
    MIN=$RES
  fi
  I=$(($I+1))
done
I=$(($I-1))
#echo $I loops
SUM=$(echo $SUM/1000 | bc -l)
MAX=$(echo $MAX/1000 | bc -l)
MIN=$(echo $MIN/1000 | bc -l)
AVG=$(echo $SUM/$I | bc -l)
echo tot: $SUM secounds
echo max: $MAX secounds
echo min: $MIN secounds
echo avg: $AVG secounds

