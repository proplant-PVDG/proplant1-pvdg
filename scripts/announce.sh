#!/bin/sh

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
        bash -c "sleep 1 && echo announce.shReadFieldFromDB > /dev/null"
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

echo $localip > /ram/ip.txt

HOST=$(readFieldFromDB "SELECT value from unit where field=\"server\"" || echo "solarportal-iplon.de")
ID=$(readFieldFromDB "SELECT value from unit where field=\"id\"" || echo "0000")

if [ "$HOST" = "solaranlagen.wfgsha.de" ]
then
  /usr/bin/wget -O /dev/null "http://$HOST:80/functions/update_ip.php?anl_id=$ID&ip_adr=$localip" >/var/log/wget.log 2>/var/log/wget2.log
else
  /usr/bin/wget -O /dev/null "http://arm9:arm9@$HOST:80/functions/update_ip.php?anl_id=$ID&ip_adr=$localip" >/var/log/wget.log 2>/var/log/wget2.log
fi
