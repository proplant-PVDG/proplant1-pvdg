#!/bin/bash
echo "TIME,SEND" > sending.csv
lastvalue=9
while read line
do
  if [ $(echo $line | grep -c "INFO posted") -ne 0 ]
  then
    pos=$(echo $line | grep -b -o "INFO posted" | awk 'BEGIN {FS=":"}{print $1}')
    time=$(echo $line | cut -c1-$pos)
    time=$(date --date="$time" "+%d.%m.%Y %T")
    if [ $lastvalue -ne 1 ]
    then
      lastvalue=1
      echo $time,0 >> sending.csv
      echo $time,1 >> sending.csv
    fi
  elif [ $(echo $line | grep -c "WARN post of") -ne 0 ]
  then
    pos=$(echo $line | grep -b -o "WARN post of" | awk 'BEGIN {FS=":"}{print $1}')
    time=$(echo $line | cut -c1-$pos)
    time=$(date --date="$time" "+%d.%m.%Y %T")
    if [ $lastvalue -ne 0 ]
    then
      lastvalue=0
      echo $time,1 >> sending.csv
      echo $time,0 >> sending.csv
    fi
  fi
done < $1
