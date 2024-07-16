#!/bin/bash
FAIL=0
while [ 1 -eq 1 ]
do
  ALIVE=$(wvdial alive 2>&1 | grep -c "Modem initialized")
  if [ $ALIVE -eq 0 ]
  then
    FAIL=$(($FAIL+1))
    if [ $FAIL -le 2 ]
    then
      bash -c "sleep 60 && echo checkModem.sh FAIL $FAIL > /dev/null"
    else
      echo $(date) Killing modem because 3th times AT fails >> /var/log/pppd.log
      /opt/iplon/scripts/killModem.sh 60
      FAIL=0
    fi
  else
    FAIL=0
    bash -c "sleep 30 && echo checkModem.sh > /dev/null"
  fi
done
