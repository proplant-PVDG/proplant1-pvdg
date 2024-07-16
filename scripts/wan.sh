#!/bin/bash

# SMS Syntax :
# arm9Solar [command] arm9Solar
# example: arm9Solar wvdial d1 && pkill -x pppd arm9Solar

HW=$(cat /etc/iplonHW)
if [ $(echo $HW | grep -ci Baltos) -eq 1 ]
then
  WANDEV=eth1
else
  WANDEV=eth0
fi

checkSMS() {
  for SMSFILE in /var/spool/sms/incoming/*
  do
    if [ "$SMSFILE" != "/var/spool/sms/incoming/*" ]
    then
      SMS=$(cat $SMSFILE 2>/dev/null)
      SMSVALID=$(echo $SMS | grep -o -w "arm9Solar" | wc -w)
      if [ $SMSVALID -eq 2 ]
      then
        COMMAND=${SMS#*arm9Solar}
        COMMAND=${COMMAND%arm9Solar}
        echo $(date) executing $COMMAND >> /var/log/smsd.log
        COMMAND=$(bash -c "$COMMAND 2>&1" 2>&1)
        echo $(date) result is $COMMAND >> /var/log/smsd.log
      else
        echo $(date) invalid sms $SMSFILE >> /var/log/smsd.log
      fi
      rm -f $SMSFILE
    fi
  done
}

readFieldFromDB() {
    local DBERROR_=1
    local T_=0
    local RSLT_=""
        local fmt_="-list"
        if [ "x$2" = "xcsv" ]; then
          fmt_="-csv"
        fi
    while [ $DBERROR_ -eq 1 -a $T_ -le 15 ]; do
      RSLT_=$(sqlite3 $fmt_ /var/spool/db "$1" 2>&1 | dos2unix)
      DBERROR_=`echo $RSLT_ | grep -ci "database is locked"`
      T_=$(($T_+1))
      if [ $DBERROR_ -eq 1 ]; then
        bash -c "sleep 1 && echo wan.shReadFieldFromDB > /dev/null"
      fi
    done
    if [ $DBERROR_ -ne 1 ]; then
      DBERROR_=`echo $RSLT_ | grep -ci "error"`
    fi
    if [ $DBERROR_ -ne 0 ]; then
      echo $RSLT_ >&2
      return 1
    else
      echo $RSLT_ 
      return 0
    fi
}

checkConnection() {
  PINGS=0
  IN=0
  while [ $PINGS -le 2 ]
  do
    IP=$(host -W 1 -t a $SERVER | awk '{print $4}')
    if [ $(echo $IP | grep -o "\." | wc -l) -eq 3 ]
    then
      if [ $2 -eq 0 ]
      then
        OLDGW=$(route -n | grep '^0\.0\.\0\.0[ \t]\+[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*[ \t]\+0\.0\.0\.0[ \t]\+[^ \t]*G[^ \t]*[ \t]' | awk '{print $2}')
        PING=`/bin/ping -s 1 -c 1 -q $IP -I $1 -w 1`
        PING=`echo $PING | grep -ci "1 received"`
      else
        NEWGW=$(route -n | grep '^0\.0\.\0\.0[ \t]\+[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*[ \t]\+0\.0\.0\.0[ \t]\+[^ \t]*G[^ \t]*[ \t]' | awk '{print $2}')
        if [ $(echo $NEWGW | grep -o "\." | wc -l) -eq 3 ]
        then
          route del default gw $NEWGW
        fi
        if [ $(echo $OLDGW | grep -o "\." | wc -l) -eq 3 ]
        then
          route add default gw $OLDGW
        fi
        PING=`/bin/ping -s 1 -c 1 -q $IP -I $1 -w 1`
        PING=`echo $PING | grep -ci "1 received"`
        if [ $(echo $OLDGW | grep -o "\." | wc -l) -eq 3 ]
        then
          route del default gw $OLDGW
        fi
        if [ $(echo $NEWGW | grep -o "\." | wc -l) -eq 3 ]
        then
          route add default gw $NEWGW
        fi
      fi
    else
      PING=0
    fi
    if [ $PING -ne 1 ]
    then
      if [ $2 -eq 0 ]
      then
        PINGS=$(($PINGS+1))
      else
        IN=$(($IN+1))
      fi
    else
      if [ $2 -eq 0 ]
      then
        PINGS=0
      else
        echo 1
        return 1
      fi
    fi
    if [ $2 -eq 0 ]
    then
      bash -c "sleep 10 && echo wan.shCheckConnection > /dev/null"
    else
      bash -c "sleep 60 && echo wan.shCheckConnection IN=$IN > /dev/null"
      if [ $IN -gt 60 ]
      then
        echo 3
        return 1
      fi
    fi
    checkSMS
  done
  echo 1
  return 1
}

ppp0Gateway() {
  echo 1 > /proc/sys/net/ipv4/ip_forward
  iptables -t nat -A POSTROUTING -o $1 -j MASQUERADE
}

TYPE=$(readFieldFromDB "SELECT value from connection where field='type'")
if [ $(cat /etc/iplonHW | grep -ci Baltos) -ne 0 ]
then
  /opt/iplon/scripts/onrisctool -k 1
  bash -c "sleep 10 && echo wan.shPowerOnMpci > /dev/null"
fi
if [ -e /dev/ttyGSM0 ]
then
  rm -f /dev/modemPPP
  rm -f /dev/modemAT
  ln -s /dev/ttyGSM3 /dev/modemPPP
  ln -s /dev/ttyGSM2 /dev/modemAT
  wvdial uc20gps
  systemctl start gpsd.service
elif [ -e /dev/ttySTICK0 ]
then
  rm -f /dev/modemPPP
  rm -f /dev/modemAT
  ln -s /dev/ttySTICK0 /dev/modemPPP
  ln -s /dev/ttySTICK2 /dev/modemAT
elif [ $(/opt/iplon/scripts/onrisctool -s | grep -ci 'Model: 212') -eq 1 -a "$TYPE" != "dsl" ]
then
  rm -f /dev/modemPPP
  rm -f /dev/modemAT
  /opt/iplon/scripts/onrisctool -p 1 -t rs232 -r
  bash -c "sleep 5 && echo wan.shPowerOnSerialModem > /dev/null"
  stty -F /dev/ttyO1 hupcl
  bash -c "sleep 5 && echo wan.shPowerOnSerialModem > /dev/null"
  stty -F /dev/ttyO1 -hupcl
  bash -c "sleep 5 && echo wan.shPowerOnSerialModem > /dev/null"
  /opt/iplon/scripts/gsmMuxd -r -p /dev/ttyO1 -b 57600 -w -m mc35 -n -s /dev/mux /dev/ptmx /dev/ptmx /dev/ptmx &
  bash -c "sleep 30 && echo wan.shStartingGsmMuxd > /dev/null"
  ln -s /dev/mux2 /dev/modemPPP
  ln -s /dev/mux1 /dev/modemAT 
  echo yes > /ram/modemSerial
elif [ -e /dev/ttyACM0 ]
then
  rm -f /dev/modemPPP
  rm -f /dev/modemAT
  ln -s /dev/ttyACM0 /dev/modemPPP
  if [ $(cat /etc/iplonHW | grep -ci Alekto2) -ne 0 ]
  then
    ln -s /dev/ttyACM2 /dev/modemAT
  else
    ln -s /dev/ttyACM3 /dev/modemAT
  fi
elif [ -e /dev/ttyUSB0 ]
then
  rm -f /dev/modemPPP
  rm -f /dev/modemAT
  ln -s /dev/ttyUSB0 /dev/modemPPP
  ln -s /dev/ttyUSB2 /dev/modemAT
fi

SERVER=$(readFieldFromDB "SELECT value from unit where field='server'")
if [ "$TYPE" == "dsl" ]
then
  echo > /etc/ppp/resolv.conf
  pdnsd-ctl config
  ppp0Gateway $WANDEV
  sleep 60 && /etc/init.d/smstools stop
  systemctl restart iplon-vpn.service
elif [ "$TYPE" == "modem" ]
then
  echo $(date) type in config is modem >> /var/log/pppd.log
  ppp0Gateway ppp0
  systemctl restart iplon-checkModem.service
  systemctl restart iplon-pppd.service
  while [ 1 -eq 1 ]
  do
    bash -c "sleep 60 && echo wan.shCheckSMS > /dev/null"
    checkSMS
  done
else
  systemctl restart iplon-vpn.service
  echo $(date) type in config is modem and dsl >> /var/log/pppd.log
  while [ 1 -eq 1 ]
  do
    ppp0Gateway $WANDEV
    checkConnection "$WANDEV" 0
    echo $(date) switching to modem because lan fails >> /var/log/pppd.log
    systemctl stop iplon-vpn.service
    ppp0Gateway ppp0
    systemctl restart iplon-checkModem.service
    systemctl restart iplon-pppd.service
    RESULT=$(checkConnection "$WANDEV" 1)
    if [ $RESULT -eq 3 ]
    then
      echo $(date) Too long at backup connection, switching back to lan >> /var/log/pppd.log
    else
      echo $(date) switching back to lan >> /var/log/pppd.log
    fi
    systemctl stop iplon-checkModem.service
    systemctl stop iplon-pppd.service
    if [ $RESULT -eq 3 ]
    then
      /opt/iplon/scripts/nwconfig.sh
    fi
    systemctl restart iplon-vpn.service
  done
fi
