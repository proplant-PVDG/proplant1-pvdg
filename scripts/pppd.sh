#!/bin/bash

function readFieldFromDB() {
    local DBERROR_=1
    local T_=0
    local RSLT_=""
        local fmt_="-list"
        if [ "$2" == "csv" ]; then
          fmt_="-csv"
        fi
    while [ $DBERROR_ -eq 1 -a $T_ -le 15 ]; do
      RSLT_=$(sqlite3 $fmt_ /var/spool/db "$1" 2>&1 | dos2unix)
      DBERROR_=`echo $RSLT_ | grep -ci "database is locked"`
      T_=$(($T_+1))
      if [ $DBERROR_ -eq 1 ]; then
        sleep 1
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

FAILS=0
while [ 1 -eq 1 ]
do
  START=$(date +%s)
  echo $(date) Starting pppd >> /var/log/pppd.log
  if [ $(cat /etc/iplonHW | grep -ci Alekto2) -ne 0 ]
  then
    wvdial fun1 2>&1
  fi
  if [ -f /etc/ppp/resolv.conf ]
  then
    echo -n > /etc/ppp/resolv.conf
  fi
  ALIVE=0
  REGISTERED=$(wvdial reg 2>&1 | grep -c "+CREG: 0,5")
  NET=`wvdial net 2>&1`
  PROVIDER=$(readFieldFromDB "SELECT value from connection where field='provider'")
  ACTENO=`echo $PROVIDER | grep -ci acteno`
  EPLUS=`echo $NET | grep -c E-Plus`
  TMOBILE=`echo $NET | grep -c T-Mobile`
  TELEKOM=`echo $NET | grep -c Telekom.de`
  HELLOMOBIL=`echo $NET | grep -c helloMobil`
  O2=`echo $NET | grep -c Willkommen`
  CELLONE=`echo $NET | grep -ci Cellone`
  HUTCH=`echo $NET | grep -ci Hutch`
  AIRTEL=`echo $NET | grep -ci AirTel`
  BPL=`echo $NET | grep -ci BPL`
  VODAFONE=`echo $NET | grep -ci Vodafone.de`
  SQ=$(wvdial sq 2>&1 | grep "+CSQ:" | awk '{print $2}')
  REGISTERED=`echo $COMGT | grep -c 'Failed to register'`
  if [ $REGISTERED -ne 0 ]
  then
    REGISTERED=0
  else
    REGISTERED=1
  fi
  IMSI=$(wvdial imsi 2>&1 | grep -A 1 ^AT+CIMI | tail -n 1)

  SQFILE=$(mktemp)
  chmod ugo+rw $SQFILE
  echo -n $REGISTERED > $SQFILE
  echo -n ',' >> $SQFILE
  echo -n $SQ >> $SQFILE
  mv -f $SQFILE /ram/sq.txt

  if [ $ACTENO -eq 1 ]
  then
    echo Acteno > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.acteno logfile /var/log/pppd.log
  elif [ $(echo $IMSI | grep -ci 20404) -eq 1 ]
  then
    echo Vodafone-M2M > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.vodafonem2m logfile /var/log/pppd.log
  elif [ $EPLUS -eq 1 ]
  then
    echo E-Plus > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.eplus logfile /var/log/pppd.log
  elif [ $TMOBILE -eq 1 -o $TELEKOM -eq 1 ]
  then
    echo T-Mobile > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.td1 logfile /var/log/pppd.log
  elif [ $HELLOMOBIL -eq 1 -o $O2 -eq 1 ]
  then
    if [ $HELLOMOBIL -eq 1 ]
    then
      echo helloMobil > /ram/provider.txt
    else
      echo 02 > /ram/provider.txt
    fi
    pppd file /opt/iplon/etc/ppp/options.o2 logfile /var/log/pppd.log
  elif [ $CELLONE -eq 1 ]
  then
    echo Cellone > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.cellone logfile /var/log/pppd.log
  elif [ $HUTCH -eq 1 ]
  then
    echo Hutch > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.hutch logfile /var/log/pppd.log
  elif [ $AIRTEL -eq 1 ]
  then
    echo Airtel > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.airtel logfile /var/log/pppd.log
  elif [ $BPL -eq 1 ]
  then
    echo BPL > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.bpl logfile /var/log/pppd.log
  elif [ $VODAFONE -eq 1 ]
  then
    echo Vodafone.de > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.vodafone logfile /var/log/pppd.log
  elif [ $FAILS -gt 9 ]
  then
    echo $(date) 9th times Simcard detection failes, trying with Vodafone-M2M >> /var/log/pppd.log
    echo Vodafone-M2M > /ram/provider.txt
    pppd file /opt/iplon/etc/ppp/options.vodafonem2m logfile /var/log/pppd.log
  fi
  END=$(date +%s)
  DIFF=$(($END-$START))
  bash -c "sleep 20 && echo pppd.sh > /dev/null"
  if [ $DIFF -gt 3600 ]
  then
    FAILS=0
  else
    FAILS=$(($FAILS+1))
  fi
  if [ $FAILS -gt 10 ]
  then
    echo $(date) Killing modem because 10th times pppd fails >> /var/log/pppd.log
    /opt/iplon/scripts/killModem.sh 30
    FAILS=0
  fi
done
