#!/bin/bash
# executed by bash 

PREPARE=/tmp/iplon/network/prepare
mkdir -p $PREPARE
rm -rf $PREPARE/*
echo >$PREPARE/static.cfg
echo >$PREPARE/zcip.cfg
echo >$PREPARE/bridge.cfg
echo >$PREPARE/wlan.cfg

setcap cap_net_raw+ep /bin/ping

readFieldFromDB() {
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


# zcip.sh shellscript documentation 
# ---------------------------------
# 
# this is the **zcip.sh** script used to configure the network on the BBB 

# check if ssh certs are missing, then generate
SSHKEYS=$(ls -l /etc/ssh | grep -ci key)
if [ $SSHKEYS -eq 0 ]
then
  echo ssh certs are missing, generate...
  dpkg-reconfigure openssh-server 
fi

# is wlan present?
WLANDEVICE=$(ip addr show | grep -ci wlan0)
AP=$(readFieldFromDB "SELECT * from connection" csv | grep -ci "wlan,ap")
WPA=$(readFieldFromDB "SELECT * from connection" csv | grep -ci "wlan,wpa")
if [ $WLANDEVICE -ne 0 ]
then
  WLANMAC=$(/opt/iplon/scripts/onrisctool -s | grep MAC3 | awk '{print $2}')
  echo "auto wlan0"                >>$PREPARE/wlan.cfg
  echo "iface wlan0 inet static"   >>$PREPARE/wlan.cfg
  echo "  address   10.43.1.100"   >>$PREPARE/wlan.cfg
  echo "  netmask   255.255.255.0" >>$PREPARE/wlan.cfg
  echo "  broadcast 10.43.1.255"   >>$PREPARE/wlan.cfg
  echo "  scope link"              >>$PREPARE/wlan.cfg
  echo "  pre-up /opt/iplon/scripts/onrisctool -w $WLANMAC || true" >>$PREPARE/wlan.cfg
  echo                             >>$PREPARE/wlan.cfg
  if [ $AP -eq 1 ]
  then
    LAN=br0
    WAN=eth1
    echo "auto br0"                  >>$PREPARE/bridge.cfg
    echo "iface br0 inet static"     >>$PREPARE/bridge.cfg
    echo "  address   10.44.1.100"   >>$PREPARE/bridge.cfg
    echo "  netmask   255.255.255.0" >>$PREPARE/bridge.cfg
    echo "  broadcast 10.44.1.255"   >>$PREPARE/bridge.cfg
    echo "  scope link"              >>$PREPARE/bridge.cfg
    echo "  bridge_ports eth0 wlan0" >>$PREPARE/bridge.cfg
    echo "  bridge_stp yes"          >>$PREPARE/bridge.cfg
    echo                             >>$PREPARE/bridge.cfg
    systemctl start hostapd.service
  elif [ $WPA -eq 1 ]
  then
    LAN=eth0
    WAN=wlan0
  else
    LAN=eth0
    WAN=eth1
  fi
else
  LAN=eth0
  WAN=eth1
fi

# we first add the route for multicasting (used by avahi and also others):
##route add -net 224.0.0.0 netmask 240.0.0.0 dev $LAN
ip route add 224.0.0.0/4 dev $LAN || echo route 224 already set...

TRUE=0

##set -e

# Helper Function to read a field from the database
# -------------------------------------------------
#


# DIP switch readout 
# ------------------
# 
# this: 
#/ dd if=/dev/misc/encoder of=/ram/switch bs=2 count=1 > /dev/null / /usr/sbin/getSwitch > /ram/switch 
# must be replaced on BBB by:
echo $(readFieldFromDB "SELECT value from unit where field=\"switchNumber\"" csv || echo 99) > /ram/switch ; chown iplon:iplon /ram/switch

# then we split up the content in two variables:
SWITCH1=`cat /ram/switch | cut -c2` SWITCH2=`cat /ram/switch | cut -c1`

# Helper Function to calculate netmask, etc 8 -> 255.0.0.0
# --------------------------------------------------------
# 
cidr2mask() {
  local i mask=""
  local full_octets=$(($1/8))
  local partial_octet=$(($1%8))

  for ((i=0;i<4;i+=1)); do
    if [ $i -lt $full_octets ]; then
      mask+=255
    elif [ $i -eq $full_octets ]; then
      mask+=$((256 - 2**(8-$partial_octet)))
    else
      mask+=0
    fi  
    test $i -lt 3 && mask+=.
  done

  echo $mask
}

# find out if we have an Ethernet (DSL) or a PPP (Modem) connection:
CONNECTION=$(readFieldFromDB "SELECT * from connection" csv || echo "dhcp,yes")
DHCP=$(echo $CONNECTION | grep -i dhcp)
DSL=$(echo $CONNECTION | grep -ci dsl)

# Calculation of hostname 
# -----------------------

# first read out the hostname field from the database:
UNITHOSTNAME=$(readFieldFromDB "SELECT value from unit where field=\"hostname\"" || echo "iGatePV")
# also read the iGate id:
UNITID=$(readFieldFromDB "SELECT value from unit where field=\"id\"" || echo "0000")

# set the resulting hostname:
hostn=$(cat /etc/hostname)
HOSTNAME=$(echo $UNITHOSTNAME$UNITID) 
/bin/hostname $UNITHOSTNAME$UNITID
sed -i "s/$hostn/$HOSTNAME/g" /etc/hosts
sed -i "s/$hostn/$HOSTNAME/g" /etc/hostname


# DHCP initialization 
# -------------------
# 
if [ $(echo $DHCP | grep -ci dhcp,yes) -eq 1 ]
then
  echo "iface $LAN inet dhcp" >$PREPARE/dhcp.cfg
  echo "iface $WAN inet dhcp" >>$PREPARE/dhcp.cfg
  if [ $WPA -eq 1 -a "$WAN" == "wlan0" ] 
  then
    echo "  pre-up /opt/iplon/scripts/onrisctool -w $WLANMAC || true" >>$PREPARE/dhcp.cfg
  fi
elif [ $(echo $DHCP | grep -ci dhcp,$LAN) -eq 1 ]
then
  echo "iface $LAN inet dhcp" >$PREPARE/dhcp.cfg
elif [ "$LAN" == "br0" -a $(echo $DHCP | grep -ci dhcp,eth0) -eq 1 ]
then
  echo "iface $LAN inet dhcp" >$PREPARE/dhcp.cfg
elif [ $(echo $DHCP | grep -ci dhcp,$WAN) -eq 1 ]
then
  echo "iface $WAN inet dhcp" >$PREPARE/dhcp.cfg
  if [ $WPA -eq 1 -a "$WAN" == "wlan0" ]
  then
    echo "  pre-up /opt/iplon/scripts/onrisctool -w $WLANMAC || true" >>$PREPARE/dhcp.cfg
  fi
fi
  
# zcip default address calculation and setting
# --------------------------------------------
# 
if [ $UNITID -gt 254 ] 
then
  MOD=$(expr $UNITID % 254)
  DIV=$(expr $UNITID / 254)
  DIV=$(($DIV+1)) 
else
  DIV=1
  MOD=$(expr $UNITID + 0)
  if [ $MOD -eq 0 ]
  then
    DIV=254
    MOD=254
  fi 
fi
  
# setting the default zcip address 
# ------------------------
# 
# do this only if above *$TRUE* == 0 (no DHCP)
  echo "auto $LAN:avahi"               >>$PREPARE/zcip.cfg
  echo "iface $LAN:avahi inet manual"  >>$PREPARE/zcip.cfg
  echo "   up /usr/sbin/avahi-autoipd -S 169.254.$DIV.$MOD --force-bind -w --debug -D $LAN" \
                                       >>$PREPARE/zcip.cfg
  echo "   down /usr/sbin/avahi-autoipd --kill $LAN" \
                                       >>$PREPARE/zcip.cfg

# delete the dhcp hook files to stop zcip on dhcp activation
# ----------------------------------------------------------
#
if [ -f /etc/dhcp/dhclient-enter-hooks.d/avahi-autoipd ]
then
  rm /etc/dhcp/dhclient-enter-hooks.d/avahi-autoipd
fi
if [ -f /etc/dhcp/dhclient-exit-hooks.d/zzz_avahi-autoipd ]
then
  rm /etc/dhcp/dhclient-exit-hooks.d/zzz_avahi-autoipd
fi

# re-adding the multicast group address 
# -------------------------------------
# 
ip route add 224.0.0.0/4 dev $LAN

# Manual Gateway definition 
# -------------------------
# 
# first read the field from the DB
GW=$(readFieldFromDB "SELECT * from connection" csv || echo "")
# if it is not 'gw,auto' take the manual value:
GW=$(echo $GW | grep -ci gw,auto)
if [ $GW -eq 0 ] 
then
  GWNAME=$(readFieldFromDB "SELECT value from connection where field=\"gw\"" || echo "auto")
  GW=1
  if [ $GWNAME == 'auto' ]
  then
    GW=0
  fi
else
  GW=0
fi
nogw() {
  return $GW
}

# setting additional IP addresses 
# -------------------------------
#  
# first fetch the number of add. IPs:
IPS=$(readFieldFromDB "SELECT count(*) from ips" csv || echo 0)

# then set them with **ip addr add** :
I=1 
while [ $I -ne $(($IPS+1)) ] 
do
  ip_=$(readFieldFromDB "SELECT ip from ips where id=$I")
  sm_=$(cidr2mask $(readFieldFromDB "SELECT subnetmask from ips where id=$I"))
  bc_=$(readFieldFromDB "SELECT broadcast from ips where id=$I")
  dv_=$(readFieldFromDB "SELECT dev from ips where id=$I")
  if [ "$LAN" == "br0" -a "$dv_" == "eth0" ]
  then
    dv_="br0"
  fi
  echo "auto $dv_:static_$I"               >>$PREPARE/static.cfg
  echo "iface $dv_:static_$I inet static"  >>$PREPARE/static.cfg
  echo "  address   $ip_ "                 >>$PREPARE/static.cfg
  echo "  netmask   $sm_ "                 >>$PREPARE/static.cfg
  echo "  broadcast $bc_ "                 >>$PREPARE/static.cfg
  echo "  scope global"                    >>$PREPARE/static.cfg
  nogw || echo "  gateway   $GWNAME "      >>$PREPARE/static.cfg
  if [ "$dv_" == "wlan0" ]
  then
    echo "  pre-up /opt/iplon/scripts/onrisctool -w $WLANMAC || true" >>$PREPARE/static.cfg
  fi
  echo                                     >>$PREPARE/static.cfg
  I=$(($I+1)) 
done

# Decide about the meaning of the rotary switches 
# -----------------------------------------------
#
# first read the switch field from the table "unit" from the database:
SWITCH=$(readFieldFromDB "SELECT value from unit where field=\"switch\"" csv || echo 0)
# detect if it is 'on', in case of error, set it to 'off'
SWITCH=$(echo $SWITCH | grep -ci on)

# IP address derived from the rotary switches 
# -------------------------------------------
#  
# overwrites ip address 
if [ $SWITCH -eq 1 ] 
then
  ID=$UNITID
  if [ $(echo $ID | cut -c2) -eq 0 -a $(echo $ID | cut -c1) -eq 0 ]
  then
    ip_=192.168.254.$SWITCH1$SWITCH2
    sm_=255.255.255.0
    bc_=192.168.254.255
  else
    ip_=192.168.$(echo $ID | cut -c1)$(echo $ID | cut -c2).$SWITCH1$SWITCH2
    sm_=255.255.255.0
    bc_=192.168.$(echo $ID | cut -c1)$(echo $ID | cut -c2).255
  fi 
  echo "auto $LAN:rotsw"                   >>$PREPARE/static.cfg
  echo "iface $LAN:rotsw inet static"      >>$PREPARE/static.cfg
  echo "  address   $ip_ "                 >>$PREPARE/static.cfg
  echo "  netmask   $sm_ "                 >>$PREPARE/static.cfg
  echo "  broadcast $bc_ "                 >>$PREPARE/static.cfg
  nogw || echo "  gateway   $GWNAME "      >>$PREPARE/static.cfg
  echo                                     >>$PREPARE/static.cfg
#else
#  echo "auto $LAN:service"                 >>$PREPARE/static.cfg
#  echo "iface eth:service inet static"     >>$PREPARE/static.cfg
#  echo "  address   10.41.1.100 "          >>$PREPARE/static.cfg
#  echo "  netmask   255.0.0.0 "            >>$PREPARE/static.cfg
#  echo "  broadcast 10.255.255.255 "       >>$PREPARE/static.cfg
#  nogw || echo "  gateway   $GWNAME "      >>$PREPARE/static.cfg
#  echo "  scope link "                     >>$PREPARE/static.cfg
#  echo                                     >>$PREPARE/static.cfg
fi




# Manual nameserver addition for LAN/DSL based setups 
# ---------------------------------------------------
# 
if [ $DSL -eq 1 ] 
then
  echo > /etc/resolv.conf

# reading resolv table to write to resolv.conf later
  NS=$(readFieldFromDB "SELECT count(*) from resolv" csv || echo 0)
  I=1
  while [ $I -ne $(($NS+1)) ]
  do
    NAMESERVER=$(readFieldFromDB "SELECT nameserver from resolv where id=$I" )
    if [ $? -eq 0 ]
	then
      echo nameserver $NAMESERVER >> /etc/resolv.conf
    fi
    I=$(($I+1))
  done
# resync time:
  echo "Doing synctime.sh... (backgrounding)"
#############################  /etc/synctime.sh & 
fi

# MSB additional IP address configuration for switch-based setups 
# ---------------------------------------------------------------
# 
if [ $SWITCH2 -eq 1 -a $SWITCH1 -eq 0 -a $SWITCH -eq 0 ] 
then
  ip address add 192.168.10.201/24 brd 192.168.10.255 dev $LAN
  echo "auto $LAN:msb"                 >>$PREPARE/static.cfg
  echo "iface eth:msb inet static"     >>$PREPARE/static.cfg
  echo "  address   192.168.10.201 "   >>$PREPARE/static.cfg
  echo "  netmask   255.255.255.0 "    >>$PREPARE/static.cfg
  echo "  broadcast 192.168.10.255 "   >>$PREPARE/static.cfg
  echo                                 >>$PREPARE/static.cfg
fi

# Protocol dependent additional IP address configuration for database setups 
# --------------------------------------------------------------------------
# 

# for MSB:
#
if [ $SWITCH2 -eq 9 -a $SWITCH1 -eq 9 -o $SWITCH -eq 1 ] 
then
    MSB=$(readFieldFromDB "SELECT count(id) from masters where name=\"MSBMasterLinux\"" || echo 0)
    if [ $MSB -ne 0 ]
    then
      if [ $SWITCH -eq 1 ]
      then
        ip address add 192.168.$SWITCH1$SWITCH2.201/24 brd 192.168.$SWITCH1$SWITCH2.255 dev $LAN
    	  echo "auto $LAN:msb"                               >>$PREPARE/static.cfg
    	  echo "iface eth:msb inet static"                   >>$PREPARE/static.cfg
    	  echo "  address   192.168.$SWITCH1$SWITCH2.201 "   >>$PREPARE/static.cfg
    	  echo "  netmask   255.255.255.0 "                  >>$PREPARE/static.cfg
    	  echo "  broadcast 192.168.$SWITCH1$SWITCH2.255 "   >>$PREPARE/static.cfg
    	  echo                                               >>$PREPARE/static.cfg
      else
	      echo "auto $LAN:msb"                 >>$PREPARE/static.cfg
    	  echo "iface eth:msb inet static"     >>$PREPARE/static.cfg
	      echo "  address   192.168.10.201 "   >>$PREPARE/static.cfg
	      echo "  netmask   255.255.255.0 "    >>$PREPARE/static.cfg
	      echo "  broadcast 192.168.10.255 "   >>$PREPARE/static.cfg
	      echo                                 >>$PREPARE/static.cfg
      fi
    fi
fi
# 
# for Voltwerk:
#
VW=$(readFieldFromDB "SELECT count(id) from masters where name=\"VoltwerkMasterLinux\"" || echo 0)
if [ $VW -ne 0 ]
then
  ip address add 192.168.0.$SWITCH1$SWITCH2/24 brd 192.168.0.255 dev $LAN
	  echo "auto $LAN:voltwerk"                      >>$PREPARE/static.cfg
	  echo "iface eth:voltwerk inet static"          >>$PREPARE/static.cfg
	  echo "  address   192.168.0.$SWITCH1$SWITCH2 " >>$PREPARE/static.cfg
	  echo "  netmask   255.255.255.0 "              >>$PREPARE/static.cfg
	  echo "  broadcast 192.168.0.255 "              >>$PREPARE/static.cfg
	  echo                                           >>$PREPARE/static.cfg
fi

# for DHCP Server:
#
DHCPSERVER=$(readFieldFromDB "SELECT value from connection where field=\"dhcpServer\"" || echo 0)
if [ $(echo $DHCPSERVER | grep -ci yes) -ne 0 -o $(echo $DHCPSERVER | grep -ci both) -ne 0 ]
then
  INTERFACES="$LAN $WAN"
else
  INTERFACES=$DHCPSERVER
  INTERFACES=$(echo $INTERFACES | sed 's/,/ /g')
fi

if [ $(echo $DHCPSERVER | grep -ci no) -ne 1 -a "$DHCPSERVER" != "" ]
then
  if [ $WLANDEVICE -ne 0 ]
  then
    DHCPSERVERSN="44"
  else
    DHCPSERVERSN="41"
  fi
  if [ $(echo $INTERFACES | grep -ci $LAN) -eq 1 ]
  then
    iptables -t nat -A POSTROUTING -o $LAN -j MASQUERADE
    if [ $(echo $DHCP | grep -ci dhcp,yes) -eq 1 -o $(echo $DHCP | grep -ci dhcp,$WAN) -eq 1 ]
    then
      iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
    fi
    echo "auto $LAN:dhcpServer"                   >>$PREPARE/static.cfg
    echo "iface $LAN:dhcpServer inet static"      >>$PREPARE/static.cfg
    echo "  address   10.$DHCPSERVERSN.2.100"     >>$PREPARE/static.cfg
    echo "  netmask   255.255.255.0"              >>$PREPARE/static.cfg
    echo "  broadcast 10.$DHCPSERVERSN.2.255"     >>$PREPARE/static.cfg
    echo                                          >>$PREPARE/static.cfg
  fi
  if [ $(echo $INTERFACES | grep -ci $WAN) -eq 1 ]
  then
    iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
    if [ $(echo $DHCP | grep -ci dhcp,yes) -eq 1 -o $(echo $DHCP | grep -ci dhcp,$LAN) -eq 1 ]
    then
      iptables -t nat -A POSTROUTING -o $LAN -j MASQUERADE
    fi
    echo "auto $WAN:dhcpServer"                   >>$PREPARE/static.cfg
    echo "iface $WAN:dhcpServer inet static"      >>$PREPARE/static.cfg
    echo "  address   10.42.2.100"                >>$PREPARE/static.cfg
    echo "  netmask   255.255.255.0"              >>$PREPARE/static.cfg
    echo "  broadcast 10.42.2.255"                >>$PREPARE/static.cfg
    echo                                          >>$PREPARE/static.cfg
  fi
fi

rm -f /tmp/iplon/network/*.cfg
mv $PREPARE/*.cfg /tmp/iplon/network
ifdown $LAN
ip addr flush $LAN
ifdown $WAN 
ip addr flush $WAN
if [ $WLANDEVICE -ne 0 ]
then
  ifdown wlan0
  ip addr flush wlan0
fi
if [ $WPA -eq 1 ]
then
  /etc/init.d/networking restart
  killall wpa_supplicant
  wpa_supplicant -Dwext -iwlan0 -c/etc/wpa_supplicant.conf -B
fi
/etc/init.d/networking restart

# Add additional routes from database 
# -----------------------------------
# 
sqlite3 /var/spool/db "CREATE TABLE IF NOT EXISTS \"main\".\"routing\" (\"id\" INTEGER, \"ip\" VARCHAR, \"subnet\" INTEGER, \"device\" VARCHAR, \"gw\" VARCHAR)" 
ROUTINGS=$(readFieldFromDB "SELECT count(*) from routing" csv || echo 0)
I=1 
while [ $I -ne $(($ROUTINGS+1)) ] 
do
  ip_=$(readFieldFromDB "SELECT ip from routing where id=$I" || echo "")
  sn_=$(readFieldFromDB "SELECT subnet from routing where id=$I" || echo "")
  dv_=$(readFieldFromDB "SELECT device from routing where id=$I" || echo "")
  if [ "$LAN" == "br0" -a "$dv_" == "eth0" ]
  then
    dv_="br0"
  fi
  via_=$(readFieldFromDB "SELECT gw from routing where id=$I" || echo "")
  if [ -z $via_ ]
  then
    ip route add $ip_/$sn_ dev $dv_
  else
    ip route delete $ip_/$sn_ dev $dv_
    ip route add $ip_/$sn_ via $via_ dev $dv_
  fi
    
  I=$(($I+1)) 
done

# Starting shorwall
SHOREWALL=$(readFieldFromDB "SELECT * from connection" csv | grep -ci "shorewall,yes")
if [ $SHOREWALL -ne 0 ]
then
  shorewall start
fi

# Add *redir* portforwardings from database 
# -------------------------------------------
# 
sqlite3 /var/spool/db "CREATE TABLE IF NOT EXISTS \"main\".\"portforwarding\" (\"id\" INTEGER, \"ip\" VARCHAR, \"lport\" INTEGER, \"cport\" INTEGER)" 
PFS=$(readFieldFromDB "SELECT count(*) from portforwarding" csv)
if [ $PFS -ne 0 ] 
then
  if [ $SHOREWALL -eq 0 ]
  then
    echo shorewall is not running, doing portforwarding!
    iptables -F
    echo 1 > /proc/sys/net/ipv4/ip_forward
    pkill -9 -x redir 
    I=1 
    while [ $I -ne $(($PFS+1)) ] 
    do
      lport_=$(readFieldFromDB "SELECT lport from portforwarding where id=$I" || echo "")
      cport_=$(readFieldFromDB "SELECT cport from portforwarding where id=$I" || echo "")
      caddr_=$(readFieldFromDB "SELECT ip from portforwarding where id=$I" || echo "")
      iptables -t nat -A PREROUTING -i $LAN -p tcp --dport $lport_ -j DNAT --to $caddr_:$cport_
      iptables -t nat -A PREROUTING -i $LAN -p udp --dport $lport_ -j DNAT --to $caddr_:$cport_
      iptables -t nat -A PREROUTING -i tunVPN -p tcp --dport $lport_ -j DNAT --to $caddr_:$cport_
      iptables -t nat -A PREROUTING -i tunVPN -p udp --dport $lport_ -j DNAT --to $caddr_:$cport_
      I=$(($I+1)) 
    done
    iptables -t nat -A POSTROUTING -o $LAN -j MASQUERADE
    iptables -t nat -A POSTROUTING -o tunVPN -s 10.0.0.0/8 -j MASQUERADE
  else
    echo shorewall is running, skipping portforwarding!
  fi
fi

# Switch usb power management to "always on" because of bugs in TI's musb IP core
# -------------------------------------------------------------------------------
#
if [ $(cat /etc/iplonHW | grep -ci BBB) -ne 0 ]
then
  echo "on" > /sys/bus/usb/devices/usb1/power/control
  echo "on" > /sys/bus/usb/devices/usb2/power/control
fi

# starting the dhcp server
if [ $(echo $DHCPSERVER | grep -ci no) -ne 0 -o "$DHCPSERVER" == "" ]
then
  systemctl stop isc-dhcp-server.service
else
  mv /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.tmp
  sed '/^INTERFACES/ d' /etc/default/isc-dhcp-server.tmp > /etc/default/isc-dhcp-server
  echo INTERFACES=\"$INTERFACES\" >> /etc/default/isc-dhcp-server
  rm /etc/default/isc-dhcp-server.tmp
  sleep 60 && systemctl restart isc-dhcp-server.service
fi
