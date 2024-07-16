#!/bin/bash

#set -x
current_time=$(date +"%Y-%m-%dT%H:%M:%SZ")

DATADIR="/opt/iplon/scripts/"
CONFDIR="/etc/openvpn/client/"
CONFFILE="/etc/openvpn/client/client.conf"
CONFTMPDIR="/tmp/"
CLOUD_IP="https://igate-ivpn.iplon.co.in"
TUNNELVPNFILE="/etc/systemd/system/tunnelvpn.service"
LOGFILE="/var/log/iplon/vpnReq.log"

cd $DATADIR
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
       bash -c "sleep 1 && echo vpn.shReadFieldFromDb $PROFILE > /dev/null"
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

if [ ! -d "$CONFDIR" ]
then
        mkdir -p $CONFDIR
fi

if [ ! -f "$TUNNELVPNFILE" ]
then
    echo "[Unit]
Description=My tunnelvpn Service
After=multi-user.target
    
[Service]
Type=idle
ExecStart=/bin/bash -c \"/usr/sbin/openvpn /etc/openvpn/client/client.conf >> /var/log/tunnelvpn.log\"
Restart=on-failure
    
[Install]
WantedBy=multi-user.target" >>$TUNNELVPNFILE
fi

iGate_ID=$(readFieldFromDB "SELECT value from unit where field=\"id\"")
Plant_desc=$(readFieldFromDB "SELECT value from unit where field=\"desc\"")
#CLOUD_IP=$(readFieldFromDB "SELECT value from unit where field=\"vpn\"")

conf_file="iGate_"$iGate_ID"_"$Plant_desc".txt"
echo $current_time > $CONFTMPDIR$conf_file

if ping -c 5 8.8.8.8 &> /dev/null
then
    sleep 10;
    if ping -c 5 10.117.0.1 &> /dev/null
    then
        echo "vpn is working fine - "$current_time >> $LOGFILE
        exit 0;
    elif [ ! -f "$CONFFILE" ]
    then
        echo "config file is not available sending request ..." >> $LOGFILE
        if [[ ($(/usr/bin/curl -k -F file=@$CONFTMPDIR$conf_file $CLOUD_IP/get_vpn.php --max-time 120 | grep -c "Originalname") -eq 1) ]];
        then
            sleep 120;
            $(/usr/bin/curl -k $CLOUD_IP/vpn/iGate_ovpn_files/${iGate_ID}.ovpn --output /etc/openvpn/client/client.conf)
            sleep 5;
            systemctl start tunnelvpn
            systemctl enable tunnelvpn
        fi
    else
        echo "Master vpn ip not ping conf file available restart tunnelvpn" >> $LOGFILE
        systemctl restart tunnelvpn
    fi
else
    echo "network is not available not able to create VPN network run script again" >> $LOGFILE
    systemctl stop tunnelvpn
    sleep 3;
    systemctl start tunnelvpn
fi

