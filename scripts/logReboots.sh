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

if [ -f /etc/resizeRoot ]
then
  if [ $(cat /etc/resizeRoot | grep -ci btrfs) -ne 0 ]
  then
    btrfs filesystem resize max /
    sync
    echo $(date) resizing done >> /mnt/jffs2/log/y.log
  elif [ $(cat /etc/resizeRoot | grep -ci ext4) -ne 0 ]
  then
    resize2fs /dev/mmcblk0p2
    sync
    echo $(date) resizing done >> /mnt/jffs2/log/y.log
  else
    echo $(date) resizing failed! >> /mnt/jffs2/log/y.log
  fi
  rm /etc/resizeRoot
fi

if [ x$(readFieldFromDB "SELECT value from unit where field='rootfsSize'") == "xmax" ]
then
  if [ $(cat /etc/iplonHW | grep -ci NUC ) -ne 0 ]
  then
    resizeFs="btrfs"
    resizeLable="NUC"
    resizeBlock=5
  else
    resizeFs="ext4"
    resizeLable="Baltos"
    resizeBlock=9
  fi
  rootDevice=$(lsblk -o NAME,FSTYPE,LABEL,SIZE -b -i | grep $resizeLable | tail -n 1 | cut -b3,3-$resizeBlock)
  sizeMax=$(lsblk -n -o SIZE -b /dev/$rootDevice | head -n 1)
  sizeIs=$(lsblk -n -o SIZE -b /dev/$rootDevice | tail -n 1)
  sizeDiff=$(echo $sizeMax-$sizeIs | bc)
  if [ $sizeDiff -gt 200000000 ]
  then
    echo $(date) resizing rootfs... >> /mnt/jffs2/log/y.log
    if [ "$resizeLable" == "NUC" ] 
    then
      (echo d; echo n; echo p; echo; echo; echo; echo a; echo 1; echo w) | fdisk /dev/$rootDevice
    else
      (echo d; echo 2; echo n; echo p; echo; echo; echo; echo w) | fdisk /dev/$rootDevice
    fi
    echo $resizeFs > /etc/resizeRoot
    sync
    echo $(date) partitioning done, rebooting for resizing... >> /mnt/jffs2/log/y.log
    reboot
  fi
fi

bash -c "sleep 10 && echo logReboots.shStartingNtp > /dev/null"
systemctl start ntp
bash -c "sleep 60 && echo logReboots.shStartedNtp > /dev/null"
if [ -f /opt/iplon/log/touch ] 
then
  DATE=$(date -r /opt/iplon/log/touch)
else
  DATE="unknown"
fi
RESTART=$(date)
DATETS=$(date +%s)
REASON=$(/usr/sbin/rc335x)
devmemiplon 0x44E00F08L w 0x233
if [ $(echo $REASON | grep -c "WDT1_RST") -ne 0 ]
then
  ERRORN=3
  ERRORT="Software watchdog"
elif [ $(echo $REASON | grep -c "GLOBAL_WARM_SW_RST") -ne 0 ]
then
  ERRORN=2
  ERRORT="Software reboot"
elif [ $(echo $REASON | grep -c "GLOBAL_COLD_RST") -ne 0 ]
then
  ERRORN=1
  ERRORT="Power loss"
else
  ERRORN=4
  ERRORT=$REASON
fi
echo Reboot because of $ERRORT at $DATE restart at $RESTART >> /opt/iplon/log/y.log
touch /opt/iplon/log/touch
echo $(/usr/sbin/sqlite3 -list /var/spool/db "SELECT value from unit where field=\"id\"") > /opt/iplon/sending/BBB_${ERRORN}_$DATETS.alr
echo BBB >> /opt/iplon/sending/BBB_${ERRORN}_$DATETS.alr
echo restart >> /opt/iplon/sending/BBB_${ERRORN}_$DATETS.alr
echo $ERRORN >> /opt/iplon/sending/BBB_${ERRORN}_$DATETS.alr
echo $ERRORT >> /opt/iplon/sending/BBB_${ERRORN}_$DATETS.alr
echo $DATETS >> /opt/iplon/sending/BBB_${ERRORN}_$DATETS.alr

chmod ugo+rw /opt/iplon/log/y.log /opt/iplon/sending/BBB_${ERRORN}_$DATETS.alr

while [ 1 -eq 1 ]
do
  touch /opt/iplon/log/touch
  bash -c "sleep 60 && echo logReboots.sh > /dev/null"
done
