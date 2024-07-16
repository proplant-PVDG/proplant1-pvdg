#!/bin/bash

##############################################################################
## Script um iGATE beim Portalserver anzumelden
##############################################################################
## 1. Sendet PASS Phrase , MAC_ID , ANLAGEN_ID und PORTAL_ID
## 2. Empfäom Server "auth.tar.gz" welches Zertifikate und Keys enthä3. Entpackt auth.tar.gz in /ram
## 4. Startet den Openvpn Client
## 5. Sendet 1Byte Pings durch den Tunnel -> Keep Alive
##############################################################################
## Changelog
## ren vpn vpn.sh Vogel 30.01.2008
## wget mit curl ersetzt Vogel 15.02.2008
## port von iGate auf BBB Vogel 04.06.2014
## mehrfach startbar Vogel 27.11.2014
##############################################################################
## V.0.1 ,iPLON GmbH , 07.12.07 C.Schwarz
## Inital Release
##############################################################################

cd /opt/iplon/etc/openvpn


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

PROFILE=$1
PINGHOST=$2

if [ $PROFILE -a $PINGHOST ]
then
  echo vpn profile is $PROFILE >> /var/log/$PROFILE.log
  echo vpn pinghost is $PINGHOST >> /var/log/$PROFILE.log
fi
sqlite3 /var/spool/db "CREATE TABLE IF NOT EXISTS \"main\".\"vpn\" (\"id\" INTEGER, \"profile\" VARCHAR, \"pinghost\" VARCHAR)"

if [ ! $PROFILE -a ! $PINGHOST ]
then
  echo Starting vpn with profile vpn and pinghost 10.0.0.1 >> /var/log/vpn.log
  /opt/iplon/scripts/vpn.sh vpn 10.0.0.1 &

  VPNS=$(readFieldFromDB "SELECT count(*) from vpn" csv || echo 0)
  I=1
  while [ $I -ne $(($VPNS+1)) ]
  do
    profile_=$(readFieldFromDB "SELECT profile from vpn where id=$I")
    pinghost_=$(readFieldFromDB "SELECT pinghost from vpn where id=$I")
    echo Starting vpn with profile $profile_ and pinghost $pinghost_ >> /var/log/$profile_.log
    /opt/iplon/scripts/vpn.sh $profile_ $pinghost_ &
    I=$(($I+1))
  done

  while [ 1 -eq 1 ]
  do
    bash -c "sleep 3600 && echo vpn.shService > /dev/null"
  done
fi

if [ ! $2 ]
then
  PINGHOST="none"
fi

FIRSTVPN=3
FIRSTPORTAL=3

anmeldenvpn()
{
  ## Post an VPN Server , Return auth.tar.gz
  cd /ram

  ANMELDEN=0
  while [ $ANMELDEN -eq 0 ]
  do
    if [ $TCP -eq 1 ]
    then
      curl --max-time 180 --output /ram/auth.tar.gz "http://$host_vpn:80/Sandbox/functions/anmelden_vpn.php?pass=`ifconfig eth0 | grep HWaddr | cut -c39-46 |sed 's/':'/''/g'`&mac_id=T`ifconfig eth0 | grep HWaddr | cut -c47-55 |sed 's/':'/''/g'`&anl_id=$anlagen_id&portal_id=$portal_id" >/var/log/curl_vpn.log 2>/var/log/curl2_vpn.log
    else
      curl --max-time 180 --output /ram/auth.tar.gz "http://$host_vpn:80/Sandbox/functions/anmelden_vpn.php?pass=`ifconfig eth0 | grep HWaddr | cut -c39-46 |sed 's/':'/''/g'`&mac_id=`ifconfig eth0 | grep HWaddr | cut -c47-55 |sed 's/':'/''/g'`&anl_id=$anlagen_id&portal_id=$portal_id" >/var/log/curl_vpn.log 2>/var/log/curl2_vpn.log
    fi
    AUTH=`ls /ram | grep -ci auth.tar.gz`
    if [ $AUTH -eq 1 ]
    then
      if [ -f /ram/client.key ]
      then
        rm /ram/client.key > /dev/null
      fi
      if [ -f /ram/client.crt ]
      then
        rm /ram/client.crt > /dev/null
      fi
      ## Cert und Key entpacken , Openvpn starten
      tar -C /ram -x -v -z -f auth.tar.gz
      CRT=`ls /ram/ | grep -ci client.crt`
      if [ $CRT -eq 1 ]
      then
        KEY=`ls /ram/ | grep -ci client.key`
        if [ $KEY -eq 1 ]
        then
          ANMELDEN=1
          if [ -f /ram/auth.tar.gz ]
          then
            rm /ram/auth.tar.gz > /dev/null
          fi
        fi
      fi
    fi
    if [ $FIRSTVPN -eq 0 ]
    then
      if [ $ANMELDEN -eq 0 ]
      then
        bash -c "sleep 30 && echo vpn.sh $PROFILE > /dev/null"
      fi
    else
      if [ $ANMELDEN -eq 0 ]
      then
        bash -c "sleep 10 && echo vpn.sh $PROFILE > /dev/null"
      fi
      FIRSTVPN=$(($FIRSTVPN-1))
    fi
  done

  ## Post an Portal Server , Return auth.tar.gz
  PORT=0
  while [ $PORT -eq 0 ]
  do
    if [ -f /var/log/curlPort.log ]
    then
      rm /var/log/curlPort.log > /dev/null
    fi
    if [ $TCP -eq 1 ]
    then
      curl --max-time 180 --output /var/log/curlPort.log "http://arm9:arm9@$host_port:80/functions/anmelden_port.php?pass=`ifconfig eth0 | grep HWaddr | cut -c39-46 |sed 's/':'/''/g'`&mac_id=T`ifconfig eth0 | grep HWaddr | cut -c47-55 |sed 's/':'/''/g'`&anl_id=$anlagen_id&portal_id=$portal_id" >/var/log/curl_port.log 2>/var/log/curl2_port.log
    else
      curl --max-time 180 --output /var/log/curlPort.log "http://arm9:arm9@$host_port:80/functions/anmelden_port.php?pass=`ifconfig eth0 | grep HWaddr | cut -c39-46 |sed 's/':'/''/g'`&mac_id=`ifconfig eth0 | grep HWaddr | cut -c47-55 |sed 's/':'/''/g'`&anl_id=$anlagen_id&portal_id=$portal_id" >/var/log/curl_port.log 2>/var/log/curl2_port.log
    fi
    PORT=`cat /var/log/curlPort.log | grep -ci 'Aufruf erfolgt'`
    if [ "$host_port" = "orakel.sybcom.net" ]
    then
      PORT=1
    fi
    if [ $FIRSTPORTAL -eq 0 ]
    then
      if [ $PORT -eq 0 ]
      then
        bash -c "sleep 30 && echo vpn.sh $PROFILE > /dev/null"
      fi
    else
      if [ $PORT -eq 0 ]
      then
        bash -c "sleep 10 && echo vpn.sh $PROFILE > /dev/null"
      fi
      FIRSTPORTAL=$(($FIRSTPORTAL-1))
    fi
  done
  cd /opt/iplon/etc/openvpn
}

## Welcher VPN Server?
host_vpn=$(readFieldFromDB "SELECT value from unit where field=\"vpn\"" || echo "mobilevpn.eu")
## Welcher Portal Server?
host_port=$(readFieldFromDB "SELECT value from unit where field=\"portal\"" || echo "solarportal-iplon.de")
## Portal ID
portal_id=$(readFieldFromDB "SELECT value from unit where field=\"portalId\"" || echo "212")
## Anlagen ID
anlagen_id=$(readFieldFromDB "SELECT value from unit where field=\"id\"" || echo "0000")
## Modem oder DSL?
DSL=$(readFieldFromDB "SELECT * from connection" | grep -ci dsl)
## TCP oder UDP bei VPN?
#if [ $DSL -eq 1 ]
#then
  TCP=1
#else
#  TCP=`cat /ram/provider.txt | grep -c Vodafone-M2M`
#fi

generatetunneltraffic()
{
  echo $PROFILE generating vpn tunnel traffic >> /var/log/$PROFILE.log
  I=1
  if [ $DSL -eq 1 ]
  then
    while [ $I -le 36 ]
    do
      /bin/ping -s 1 -c 1 -q $PINGHOST > /dev/null &
      bash -c "sleep 10 && echo vpn.sh $PROFILE > /dev/null"
      I=$(($I+1))
    done
  else
    while [ $I -le 12 ]
    do
      /bin/ping -s 1 -c 1 -q $PINGHOST > /dev/null &
      bash -c "sleep 30 && echo vpn.sh $PROFILE > /dev/null"
      I=$(($I+1))
    done
  fi
}

if [ "$PROFILE" == "vpn" ]
then
  anmeldenvpn
  if [ $TCP -eq 1 ]
  then
    TUNDEV=$(cat /opt/iplon/etc/openvpn/client_tcp.conf | grep 'dev tun' | grep -v '#' | grep -v ';' | awk '{print $2}')
    TUNDEV=$(echo "$TUNDEV"|tr -d '\r')
    openvpn --remote $host_vpn 443 --config /opt/iplon/etc/openvpn/client_tcp.conf &
  else
    TUNDEV=$(cat /opt/iplon/etc/openvpn/client.conf | grep 'dev tun' | grep -v '#' | grep -v ';' | awk '{print $2}')
    TUNDEV=$(echo "$TUNDEV"|tr -d '\r')
    openvpn --remote $host_vpn 443 --config /opt/iplon/etc/openvpn/client.conf &
  fi
else
  TUNDEV=$(cat /opt/iplon/etc/openvpn/$PROFILE.conf | grep 'dev tun' | grep -v '#' | grep -v ';' | awk '{print $2}')
  TUNDEV=$(echo "$TUNDEV"|tr -d '\r')
  openvpn --config /opt/iplon/etc/openvpn/$PROFILE.conf &
fi
echo tunneldevice for profile $PROFILE is $TUNDEV >> /var/log/$PROFILE.log
VPNPID=$!
if [ "$PINGHOST" != "none" ]
then
  generatetunneltraffic
else
  bash -c "sleep 300 && echo vpn.shNoGenerateTunnelTraffic $PROFILE > /dev/null"
fi

## Ping durch den Tunnel um VPN aufrecht zu erhalten.
PINGS=0
IN=1
EXIT=0
while [ $IN -eq 1 ]
do
  VPN=`ifconfig | grep $TUNDEV -ci`
  if [ $VPN -eq 0 ]
  then
    EXIT=$(($EXIT+1))
    echo $(date) Killing openvpn because no tun device >> /var/log/$PROFILE.log
    kill $VPNPID
    bash -c "sleep 10 && echo vpn.sh $PROFILE > /dev/null"
    kill -9 $VPNPID
    if [ $DSL -eq 1 -a "$PROFILE" == "vpn" ]
    then
      anmeldenvpn
    fi
    if [ $EXIT -le 10 ]
    then
      if [ "$PROFILE" == "vpn" ]
      then
        if [ $TCP -eq 1 ]
        then
          openvpn --remote $host_vpn 443 --config /opt/iplon/etc/openvpn/client_tcp.conf &
        else
          openvpn --remote $host_vpn 443 --config /opt/iplon/etc/openvpn/client.conf &
        fi
      else
        openvpn --config /opt/iplon/etc/openvpn/$PROFILE.conf &
      fi
      VPNPID=$!
      if [ "$PINGHOST" != "none" ]
      then
        generatetunneltraffic
      fi
    elif [ $DSL -eq 0 ]
    then
      echo $(date) Killing pppd because no tun device >> /var/log/$PROFILE.log
      pkill -x pppd
      bash -c "sleep 10 && echo vpn.sh $PROFILE > /dev/null"
      pkill -9 -x pppd
      IN=0
    else
      EXIT=0
    fi
  elif [ "$PINGHOST" != "none" ]
  then
    EXIT=0
    if [ $DSL -eq 1 ]
    then
      bash -c "sleep 50 && echo vpn.sh $PROFILE > /dev/null"
    else
      if [ $PINGS -eq 0 ]
      then
        bash -c "sleep 150 && echo vpn.sh $PROFILE > /dev/null"
      else
        bash -c "sleep 75 && echo vpn.sh $PROFILE > /dev/null"
      fi
    fi
    PING=`/bin/ping -s 1 -c 1 -q $PINGHOST`
    PING=`echo $PING | grep -ci "1 received"`
    if [ $PING -ne 1 ]
    then
      PINGS=$(($PINGS+1))
    else
      PINGS=0
    fi
    if [ $DSL -eq 1 ]
    then
      bash -c "sleep 50 && echo vpn.sh $PROFILE > /dev/null"
    else
      if [ $PINGS -eq 0 ]
      then
        bash -c "sleep 150 && echo vpn.sh $PROFILE > /dev/null"
      else
        bash -c "sleep 75 && echo vpn.sh $PROFILE > /dev/null"
      fi
    fi
    if [ $PINGS -gt 3 ]
    then
      if [ $PINGS -gt 6 -o $DSL -ne 1 ]
      then
        if [ $DSL -eq 1 ]
        then
          echo $(date) Killing openvpn because no ping >> /var/log/$PROFILE.log
          kill $VPNPID
          bash -c "sleep 10 && echo vpn.sh $PROFILE > /dev/null"
          kill -9 $VPNPID

          if [ "$PROFILE" == "vpn" ]
          then
            anmeldenvpn
            if [ $TCP -eq 1 ]
            then
              openvpn --remote $host_vpn 443 --config /opt/iplon/etc/openvpn/client_tcp.conf &
            else
              openvpn --remote $host_vpn 443 --config /opt/iplon/etc/openvpn/client.conf &
            fi
          else
            openvpn --config /opt/iplon/etc/openvpn/$PROFILE.conf &
          fi
          VPNPID=$!
          generatetunneltraffic
        else
          echo $(date) Killing pppd because no ping >> /var/log/$PROFILE.log
          pkill -x pppd
          bash -c "sleep 10 && echo vpn.sh $PROFILE > /dev/null"
          pkill -9 -x pppd
          IN=0
        fi
        PINGS=0
      fi
    fi
  else
    EXIT=0
    bash -c "sleep 10 && echo vpn.shNoPinghost $PROFILE > /dev/null"
  fi
done
