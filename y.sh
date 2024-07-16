#!/bin/bash
(

export LANG=C

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

# fetch a value-field pair from a table constructed according to this, e.g. "unit"
function keyValue {
          readFieldFromDB "SELECT value from $1 where field=\"$2\""
}

# reset watchdog counter with:
#systemctl reset-failed
# distinction between iGate and beaglebone startup
# ------------------------------------------------
#
if [ $OSTYPE != "linux-gnueabihf" -a $OSTYPE != "linux-gnu" ]
# this is for iGate:
then
# increase stack, heap and filesystem limits
  ulimit -v 18000
  ulimit -d 9000
  ulimit -m 9000
  ulimit -a > /ram/ulimit.txt
# use this sqlite binary:
  SQLITE3=/usr/sbin/sqlite3
# read the dip switches with this binary:
  GETSWITCH=/usr/sbin/getSwitch
# to set some FPGA IO configurations (FTT/485, USB) etc.
  SETIO=tm
# this is the path of the watchdog device:
  WDD=/dev/misc/ns9xx0_wdt
# we dont need suo on the iGate:
  SUDO=""
# to configure the RS-485 data enable time interval:
  UART485=/usr/bin/uart485
# LED switching on iGate:
  LEDS=/usr/sbin/leds
# reboot on iGate is simple:
  REBOOT=reboot
else
# define  iplon installation base directory:
  export PX=$(pwd)
#
# we have sqlite3 on debian:
  SQLITE3=/usr/bin/sqlite3
# but the dip switches are not existing 
  GETSWITCH="keyValue unit switchNumber"
  if [ $($GETSWITCH | grep -ci "auto") -eq 1 ]
  then
    GETSWITCH="echo 99"
  fi
# and IOs currently dont need to be set
  SETIO="/opt/iplon/scripts/hub-ctrl -b 001 -d 002"
# this is the wathdog device:
  WDD=/dev/watchdog
# we need sudo e.g. to stop the watchdog daemon with systemctl:
  SUDO="sudo "
# no need for uart485 (there is no 485 yet):
  UART485="echo uart485 "
# unfortunately no LEDs yet (could be changed!):
  LEDS="echo leds "
# reboot cleanly:
  REBOOT="$SUDO shutdown -r now"
  echo "running on " $OSTYPE
# this is for injecting a bunch of lua level corrections, like
# manipulating os.execute paths and otehre things under debian:
  export LUA0FILE=$PX/jffs2/solar/lua0file.lua
# this is to give modbus enough timeout in simulation environments.
# @todo: remove this for production !?!
  EXTENDEDTIMEOUTS="400"

# make sure some important directories really exist:
  if [ ! -d /tmp/ram ] 
  then
    mkdir /tmp/ram
    ln -s /tmp/ram /ram
  fi

  if [ ! -e /tmp/varlog ] 
  then
    mkdir /tmp/varlog
    ln -s /tmp/varlog $PX/var/log
  fi
  mkdir -p /tmp/pv/ram
  mkdir -p /tmp/pv/var/log
  mkdir -p /tmp/pv/var/lock
  mkdir -p /tmp/pv/var/run
  mkdir -p /tmp/pv/tmp  
#currently there is no lon under debian:  
  echo 0 > /ram/lon
  
fi

#distinction iplon Hardware
iplonHW=$(cat /etc/iplonHW)
shortWD=$(cat /proc/cpuinfo | grep Hardware | grep -ci bcm2709)

# updating the hardware watchdog system
function feedwd {
  if [ $OSTYPE != "linux-gnueabihf" -a $OSTYPE != "linux-gnu" ]
  then
    $SUDO dd if=/dev/zero of=$WDD bs=1 count=1 2> /dev/null
  elif [ $shortWD -eq 1 ]
  then
    kill $WDPID
    echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 && sleep 10 && echo >&5 &
    WDPID=$!
  else
    echo >&5
  fi
#  echo "feeding the watchdog"
}


# activating the software watchdog if hardware watchdog not supported
SOFTDOG=$($SUDO dmidecode -t 2 | grep -ci 'NUC6i5SYB\|NUC6i3SY')
if [ $SOFTDOG -ne 0 ]
then
  $SUDO modprobe softdog
  $SUDO systemctl daemon-reexec
fi

# Setting watchdog to 10 Minutes
if [ $($SUDO wdctl /dev/watchdog -s 600 2>&1 | grep -ci Inappropriate) -ne 0 ]
then
  $SUDO wdctl /dev/watchdog0 -s 600
  WDD=/dev/watchdog0
fi
$SUDO chown iplon:iplon $WDD
exec 5>$WDD
feedwd


# starting up LED blinking
if [ $(echo $iplonHW | grep -ci Baltos) -ne 0 ]
then
  $SUDO /opt/iplon/scripts/onrisctool -l app:2 &
fi

# this is optional for automatically posting all datapoint values to a local redis database:
##export RRIP=127.0.0.1 
##export RRPORT=6379

# global function definitions
# ---------------------------
#
# on termination of this shell script,
# cleanup all its children:
# 
function clean {
# kill all instances of wrprot which are currently running:
  $SUDO kill $(lsof -t /usr/sbin/wrprot) 2> /dev/null
# kill all processes in our process group, e.g. all children:  
  kill 0
# then leave:  
  exit 1 
}
# always call "clean" when terminating this shellscript:
trap 'clean' SIGINT SIGTERM

# fetch us some values from sqlite3, 
# parameters are field, table, [condition]
function sqlGet {
	if [ $# = 2 ]
	then
	  readFieldFromDB "SELECT $1 from $2"
	fi
	if [ $# = 3 ]
	then
	  readFieldFromDB "SELECT $1 from $2 where $3"
	fi
}

# shortcut function for defining the current master
function setMaster {
    MASTER="$1"
    MASTERBAUD1="$2"
    echo "$2" > /ram/baud1.txt
    MASTERUART1="$3"
    MASTERDEVICE1="$4"
}

# an alarm has happend, enter the text in y.log, write a mail 
# and an alr-File to be sent to the Portal,
#
# parameters are mailfile name, logtext, error number, error text, scope, type
function handleAlarm {
       echo handling alarm "$2"
       local yFile=$PX/mnt/jffs2/log/y.log
	echo "$2" at $(date) >> $yFile
	
	local ANLAGENID=$ALI
	local PORTAL=$PORTAL
	local PORTALID=$PORTALID
	local mailFile=$PX/mnt/jffs2/sending/$1.mail

	echo $ANLAGENID at $PORTAL > $mailFile
	echo >> $mailFile
	echo >> $mailFile
	echo "$2" >> $mailFile
	echo $PORTALID >> $mailFile
	echo >> $mailFile
	echo >> $mailFile

	local DATETS=$(date +%s)
	local ERRORN=$3
	local ERRORT="$4"

	local alrFile=$PX/mnt/jffs2/sending/iGate_${ERRORN}_$DATETS.alr
	echo $ANLAGENID > $alrFile
	echo "$5" >> $alrFile            ## e.g. "iGate"
	echo "$6" >> $alrFile            ## e.g. "crash"
	echo $ERRORN >> $alrFile
	echo $ERRORT >> $alrFile
	echo $DATETS >> $alrFile
       echo handling alarm "$2" finished
}

#wating for the network comming up
NWWAIT=0
while [ $(systemctl is-active iplon-nw.service | grep -ci activating) -ne 0 -a $NWWAIT -le 50 ]
do
  feedwd
  if [ $(echo $iplonHW | grep -ci Baltos) -ne 0 ]
  then
    $SUDO /opt/iplon/scripts/onrisctool -l app:2
  fi
  sleep 1
  NWWAIT=$(($NWWAIT+1))
done

ip addr show > /ram/ipsAtYstartup.txt

# Executive part of y.sh: script actions
# --------------------------------------
#
# this moves us to /home/iplon... (for whatever reason !?!)
cd ~
#

#
# synchronization between sqlite database and filesystem
# ------------------------------------------------------

# we add all cfg file from certain directories into the cfgdata table,
# if they are not already found in there:
#
echo "Checking Database files..."
CFGSDB=$(sqlGet path cfgdata)
FILELIST="$(find -L $PX/jffs2/solar -name '*.cfg') $(find -L $PX/jffs2/solar -name '*.lst') $(find -L $PX/jffs2/solar -name '*.nvt') $(find -L $PX/jffs2/solar -mindepth 2 -name '*.lua' -not -path $PX'/jffs2/solar/wrs/*' -not -path $PX'/jffs2/solar/display/*' -not -path $PX'/jffs2/solar/lua/*')"
if [ $(arch | grep -ci x86) -ne 0 ]
then
  FILELIST="$FILELIST $(find -L /etc/ddtcfg/plants -name '*.yaml') $(find -L /etc/ddtcfg -name '*.yaml')"
fi
I=1
for CFG in $FILELIST;
do
  X=$(echo $CFGSDB | grep -c $CFG)
  if [ $X -eq 0 ]
  then
    echo Adding $CFG ...
    readFieldFromDB "INSERT INTO cfgdata (path) VALUES(\"$CFG\")"
  fi
  I=$(($I+1))
done

#create tables if they are not exists
readFieldFromDB "CREATE TABLE IF NOT EXISTS fileActions(sourcePath VARCHAR,targetPath VARCHAR,action VARCHAR)"
readFieldFromDB "CREATE TABLE IF NOT EXISTS logging(path VARCHAR,id VARCHAR,format VARCHAR)"

#
# sometimes the column "config" does not yet exist in the table "masters",
# add it if needed:
# 
readFieldFromDB "alter table masters add column 'config' VARCHAR"

# always call cfgSync on y.sh (re)start:
#
echo "Doing Database Sync..."
cd $PX/mnt/jffs2/cfgSync
$SUDO ./cfgSync

# now bring us to the directory where everything happens:
cd $PX/mnt/jffs2/solar
# and feed the watchdog for the first time:
feedwd

# depending on the commandline arguments, later sleep or not:
if [ "$1" == "nosleep" ]
then
  SLEEPTIME=0
else  
  SLEEPTIME=1
fi

# on iGate this is to wait until some other services are up and to
# prevent an endless loop in case of a crash of this script:
sleep $((30*$SLEEPTIME))

# quickly feed the dog again:
feedwd

# here we fetch some basic configuration from the database, like
# iGate id, portal name and id and the like:
export ALI=$(keyValue unit id)             ; echo ALI  is $ALI           ; echo $ALI > /ram/ali.txt
export DESC=$(keyValue unit desc)         ; echo DESC is $DESC          ; echo $DESC > /ram/desc.txt
export SERVER=$(keyValue unit server)     ; echo SERVER is $SERVER      ; echo $SERVER > /ram/server.txt
export PORTAL=$(keyValue unit portal)     ; echo PORTAL is $PORTAL      ; echo $PORTAL > /ram/portal.txt
export PORTALID=$(keyValue unit portalId) ; echo PORTALID is $PORTALID  ; echo $PORTALID > /ram/portalid.txt

#handleAlarm "ystartup" "y.sh startup" 1 "y.sh startup" "iGate" "startup"

# this decides about the use of the dip switches on iGate
SWITCH=$(keyValue unit switch)  ; SWITCH=$(echo $SWITCH | grep -c on) ; export SWITCH

#export MASTERDEBUG=YES
#export MASTERRETRIES=5

# on iGate we must physically read the dip switches now:
$GETSWITCH > /ram/switch
SWITCH1=$(cat /ram/switch | cut -c2)
SWITCH2=$(cat /ram/switch | cut -c1)

# if one of the masters is a fronius master using a USB serial device,
# the device must be monitored for changes of the USB device data -
# this flag records the Fronius master's master id for later chacking:
FRUSBWATCH=0

# starting meteo control export when in sending table
if [ $(readFieldFromDB "select count(*) from sending where format='mc'") -ne 0 ]
then
  echo starting meteo control export service imet
  $SUDO systemctl restart imet.service
fi

#
# Special protocol IP subnet treatments
# -------------------------------------

# do some ip configuration for specific protocols, here MSB and Voltwerk, which are
# expected in certain IP subnets that are cared for here, also
# proxy rules are adopted in /etc/httpd.conf.
#
# @todo: this will make trouble on beaglebone !!!
#
if [ $SWITCH -eq 1 ]
then
  MSB=$(sqlGet "count(id)" "masters" "name=\"MSBMasterLinux\"")
  if [ $MSB -ne 0 ]
  then
    ip address add 192.168.$(expr $SWITCH1$SWITCH2 + 0).201/24 brd 192.168.$SWITCH1$SWITCH2.255 dev eth0
    REP=$(cat $PX/etc/httpd.conf | grep wr1)
    REP=${REP%.*}
    REP=${REP#*168.}
    sed -i "s#\.$REP\.#\.$(expr $SWITCH1$SWITCH2 + 0)\.#g" $PX/etc/httpd.conf
  fi
  VW=$(sqlGet "count(id)" "masters" "name=\"VoltwerkMasterLinux\"")
  if [ $VW -ne 0 ]
  then
    ip address add 192.168.0.$(expr $SWITCH1$SWITCH2 + 0)/24 brd 192.168.0.255 dev eth0
    REP=$(cat $PX/etc/httpd.conf | grep ag1)
    REP=${REP%:*}
    REP=${REP#*168.0.}
    sed -i "s#\.$REP:#\.1$(expr $SWITCH1$SWITCH2 + 0):#g" $PX/etc/httpd.conf
  fi
# 
# DIP switch based protocol selection tables
# ------------------------------------------
#  

elif [ $SWITCH2 -eq 0 ] 
then
  if [ $SWITCH1 -eq 1 ] ;  then setMaster YasdiMasterLinux         1200   833000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 2 ] ;  then setMaster KacoMasterLinux          9600   104000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 3 ] ;  then setMaster SMMasterLinux           19200    53500  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 4 ] ;  then setMaster SWMasterLinux            9600   104000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 5 ] ;  then setMaster BluePlanetMasterLinux    9600   104500  /dev/usb/tts;   fi
  if [ $SWITCH1 -eq 6 ] ;  then setMaster KostalMasterLinux       19200    53500  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 7 ] ;  then setMaster YasdiMasterLinux15       1200   833000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 8 ] ;  then setMaster SolarStarMasterLinux     1200   833000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 9 ] ;  then setMaster FroniusMasterLinux      19200    53500  /dev/usb/tts/0; fi
elif [ $SWITCH2 -eq 1 ]
then
  if [ $SWITCH1 -eq 0 ] ;  then setMaster 833000   1200 MSBMasterLinux            /dev/ttyS/1 ;   
    ip address add 192.168.10.201/24 brd 192.168.10.255 dev eth0
  fi
  if [ $SWITCH1 -eq 1 ] ;  then setMaster STMasterLinux           19200    53500  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 2 ] ;  then setMaster KostaliGAKMasterLinux    4800   208250  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 3 ] ;  then setMaster UssMasterLinux         115200    51990  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 4 ] ;  then setMaster DiehlMasterLinux        19200    51500  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 5 ] ;  then setMaster LtiMasterLinux           1200   833000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 6 ] ;  then setMaster SiemensMasterLinux       9600   104000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 7 ] ;  then setMaster EffektaMasterLinux       9600   104000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 8 ] ;  then setMaster ModbusMasterLinux        9600   104000  /dev/ttyS/1 ;   fi
  if [ $SWITCH1 -eq 9 ] ;  then setMaster SharpMasterLinux        38400    26000  /dev/ttyS/1 ;   fi
elif [ $SWITCH2 -eq 2 ]
then
  if [ $SWITCH1 -eq 0 ] ;  then setMaster PoweroneMasterLinux     19200    52000  /dev/ttyS/1 ;   fi
fi

# read from this file if we have the LonWorks option installed:
LON=$(cat /ram/lon)
# old ha-based LonMaster has id 9999
LONMASTERID=9999

# Treatment of the entries in the "masters" table
# -----------------------------------------------
#
# sqlite3 based configuration of the system, activated either by 
# setting the field "switch" in table "unit" to 1 or by 
# a dip switch configuration of 9/9:
if [ $SWITCH2 -eq 9 -a $SWITCH1 -eq 9 -o $SWITCH -eq 1 ]
then
# how many masters do we want? 
  MASTERS=$(readFieldFromDB "SELECT COUNT(*) from masters")
# the loop variable:  
  I=1
# this is a for loop effectively:  
  while [ $I -le $MASTERS ]
  do
# we are in directory .../jffs2/solar, so the master name also is the name of
# a symlink in the local directory pointing either to wrprot or to a
# master binary for e.g. Yasdi or the like:
    TEMPMASTER=./$(sqlGet name masters "id=$I")
# skip the following lines if it's a LonMaster and we don't really have Lon:
    if [ $(echo $TEMPMASTER | grep -c LonMasterLinux) -ne 1 -o $LON -eq 1 ]
# i.e. either we have Lon, or we are not a Lon master in this turn:
    then
#
# let us fill out a table entry for this master to 
# be used later when the master is started:
#
# * the symlink / binary 
# * the serial device, e.g. /dev/tty0
# * the power reduction configuration string
# * the additional configuration string
# * the directory for execution
# * the two timeouts for monitoring the application
# * baudrate
# * uart485 value
#
	  eval KILLMASTER${I}=$TEMPMASTER
      eval MASTERDEVICE${I}=$(sqlGet device     masters "id=$I")
      eval MASTERWRNUM${I}=$(sqlGet  inverters  masters "id=$I")
      eval PDELIMIT${I}=$(sqlGet     pdelimit   masters "id=$I")
      eval MASTERCONFIG${I}=$(sqlGet config     masters "id=$I")
      eval MASTERPATH${I}=$PX/mnt/jffs2/solar
      eval TMOUTMASTER${I}=600
      eval TMOUTRHAPSODY${I}=1800
      eval WAITMASTER${I}=18
      eval TMPFILEMASTER${I}=/ram/master$I.watch
      eval TMPFILERHAPSODY${I}=/ram/rhapsody$I.watch
      eval MASTERBAUD${I}=$(sqlGet    baud      protocols "name=\"${TEMPMASTER#*/}\"")
      eval MASTERUART${I}=$(sqlGet    uart      protocols "name=\"${TEMPMASTER#*/}\"")
      echo ${TEMPMASTER#*/} > /ram/master$I
      echo $((MASTERBAUD$I)) > /ram/baud$I.txt
# MSB masters need special treatment:	  
      if [ $(echo $TEMPMASTER | grep -c MSBMasterLinux) -eq 1 -a $SWITCH -eq 0 ]
      then
        ip address add 192.168.10.201/24 brd 192.168.10.255 dev eth0
      fi
      #I=$(($I+1))
    fi
# the LonMaster needs to be noted:	
    if [ $(echo $TEMPMASTER | grep -c LonMasterLinux) -eq 1 -a $LON -eq 0 ]
    then
      LONMASTERID=$I
    fi
# increment the counter for the next master:	
    I=$(($I+1))
  done
else
# this is the "single master selcted by dip switch" configuration option:
  MASTERS=1
  KILLMASTER1=./$MASTER
  MASTERWRNUM1=$(readFieldFromDB "SELECT inverters from masters where id=1")
  PDELIMIT1=$(readFieldFromDB "SELECT pdelimit from masters where id=1")
  MASTERCONFIG1=$(readFieldFromDB "SELECT config from masters where id=1")
  MASTERPATH1=$PX/mnt/jffs2/solar
  TMOUTMASTER1=600
  TMOUTRHAPSODY1=1800
  WAITMASTER1=18
  TMPFILEMASTER1=/ram/master1.watch
  TMPFILERHAPSODY1=/ram/rhapsody1.watch
  echo $MASTER > /ram/master1
fi

# was this for switching on USB power ??
sleep $((2*$SLEEPTIME))
#tm 17 2
sleep $((3*$SLEEPTIME))

# reset some crash / watchdog / monitoring counters:
CRASHSM=0
CRASHSS=0
WDBINKILL=0
MASTERWRNUMALL=0

#if [ $MASTER != "BluePlanetMasterLinux" -a $MASTER != "FroniusMasterLinux" -a -f /dev/usb/tts/0 ]
#then
#  cd $PX/mnt/jffs2/sniffer
#  ./Sniffer &
#fi

# 
# Configuration of the LonMaster
# ------------------------------
#
# give Lon a special treatment:
if [ $LON -eq 1 ]
then
  LONMaster=`readFieldFromDB "SELECT count(id) from masters where name=\"LonMasterLinux\""`
  if [ $LONMaster -eq 1 ]
  then
  # if the swiches are used for protocol selection (none is on "9" and "switch" in unit table is 0),
  # then use the last entry of the masters table to configure the LonMaster:
    if [ $SWITCH2 -ne 9 -o $SWITCH1 -ne 9 ] 
    then 
      if [ $SWITCH -eq 0 ]
      then
        I=$(($MASTERS+1))
        MASTERS=$(($MASTERS+1))
        eval KILLMASTER${I}=./$(readFieldFromDB "SELECT name from masters where id=$I")
        eval MASTERDEVICE${I}=$(readFieldFromDB "SELECT device from masters where id=$I")
        eval MASTERWRNUM${I}=$(readFieldFromDB "SELECT inverters from masters where id=$I")
        eval PDELIMIT${I}=$(readFieldFromDB "SELECT pdelimit from masters where id=$I")
        eval MASTERCONFIG${I}=$(readFieldFromDB "SELECT config from masters where id=$I")
        eval MASTERPATH${I}=$PX/mnt/jffs2/solar
        eval TMOUTMASTER${I}=600
        eval TMOUTRHAPSODY${I}=1800
        eval WAITMASTER${I}=18
        eval TMPFILEMASTER${I}=/ram/master$I.watch
        eval TMPFILERHAPSODY${I}=/ram/rhapsody$I.watch
        TEMP=KILLMASTER$I
        TEMP2=$(eval echo \$$TEMP)
        eval MASTERBAUD${I}=$(readFieldFromDB "SELECT baud from protocols where name=\"${TEMP2#*/}\"")
        eval MASTERUART${I}=$(readFieldFromDB "SELECT uart from protocols where name=\"${TEMP2#*/}\"")
        echo ${TEMP2#*/} > /ram/master$I
        echo $((MASTERBAUD$I)) > /ram/baud$I.txt
      fi
    fi
  fi
fi

I=$(($MASTERS+1))
MASTERS=$(($MASTERS+1))

# Configuration of the "Sending" master
# -------------------------------------
#
eval TMOUTMASTER${I}=1800                       #timeout in seconds
eval WAITMASTER${I}=18
eval TMPFILEMASTER${I}=/ram/sending.watch       #file to monitor
eval KILLMASTER${I}=./Sending                   #process to kill
eval MASTERPATH${I}=$PX/mnt/jffs2/sending
eval MASTEREXTENDEDTIMEOUTS${I}=400
echo Sending > /ram/master$I

DISPLAY=$(readFieldFromDB "SELECT count(*) from display")
DBERROR=`echo $DISPLAY | grep -ci "error"`
if [ $DBERROR -ne 1 -a $DISPLAY -ne 0 ]
then
  I=$(($MASTERS+1))
  MASTERS=$(($MASTERS+1))
  eval TMOUTMASTER${I}=600                       #timeout in seconds
  eval TMOUTRHAPSODY${I}=1800
  eval WAITMASTER${I}=18
  eval TMPFILEMASTER${I}=/ram/master$I.watch       #file to monitor
  eval TMPFILERHAPSODY${I}=/ram/rhapsody$I.watch
  eval KILLMASTER${I}=./Display                       #process to kill
  eval MASTERPARA${I}="-s\ virtual"
  eval MASTERPATH${I}=$PX/mnt/jffs2/display
  echo Display > /ram/master$I
fi

echo $MASTERS > /ram/masters

I=1
VWPORT=5001

## shell function to check required USB serial devices
## and retry connection by power cycling:
checkusb() {
 ## fetch those master-devices from sqlite that are connected via USB:
 local usbdevices=$(readFieldFromDB "SELECT device from masters;" | grep ttyUSB)
 ## max. 3 retries reconnecting the USB subsystem:
 for retries in 1 2 3; do
   local mustreset=false
   ## check all USB serial devices mentioned in the master list:
   for y in $usbdevices; do
     if [ ! -c $y ]
     then
       echo the file $y does not exist at $(date) >> $PX/mnt/jffs2/log/y.log
       echo the file $y does not exist at $(date)
       mustreset=true
     fi
   done
   if ! $mustreset
   then
     break
   else
     echo resetting USB at $(date) >> $PX/mnt/jffs2/log/y.log
     echo resetting USB at $(date)
     if [ $(echo $iplonHW | grep -ci Baltos) -ne 0 ]
     then
       $SETIO -P 1 -p 0 # USB Port 2 at Baltos
       $SETIO -P 2 -p 0 # USB Port 2 at Baltos
       sleep 2
       $SETIO -P 1 -p 1
       $SETIO -P 2 -p 1
       sleep 6
     elif [ $(echo $iplonHW | grep -ci iGate) -ne 0 ]
     then
       $SETIO 17 3 > /dev/null    # power USB off
       sleep 2            # keep 1 sec. without power
       $SETIO 17 2 > /dev/null    # power USB on
       sleep 6            # wait 4 seconds for re-enumeration
     fi
   fi
 done
}

#checkusb

# Start of the masters that have been prepared up to this point
# -------------------------------------------------------------
#

while [ $I -le $MASTERS ]
do
  feedwd
  sleep $((30*$SLEEPTIME))
  feedwd
# enter the master's cwd:  
  TEMP=MASTERPATH$I
  cd $(eval echo \$$TEMP)
# prepare its watch file:
  TEMP=TMPFILEMASTER$I
  touch $(eval echo \$$TEMP)
# the callable symlink or binary:
  TEMP=KILLMASTER$I
# all masters except pvha and Display have contain the word "Master":
  if [ $(echo $(eval echo \$$TEMP) | grep -c Master) -eq 1 -o $(echo $(eval echo \$$TEMP) | grep -c Display) -eq 1 ]
  then
# prepare the masters "rhapsody" - watch file
    TEMP=TMPFILERHAPSODY$I
    touch $(eval echo \$$TEMP)
# and export master id and the soap communication port as environment data:
    export MASTERID=$I
    echo "export MASTERID $I"
    export MASTERPORT=$(($I+10500))
    TEMP=KILLMASTER$I
# special Variables for Voltwerk:
    if [ $(echo $(eval echo \$$TEMP) | grep -c VoltwerkMasterLinux) -eq 1 ]
    then
      export MASTERDEVICE=192.168.0.1$SWITCH1$SWITCH2:$VWPORT
      echo "export MASTERDEVICE 192.168.0.1$SWITCH1$SWITCH2:$VWPORT"
      VWPORT=$(($VWPORT+100))
# special treatment for Fronius:
	elif [ $(echo $(eval echo \$$TEMP) | grep -c FroniusMasterLinux) -eq 1 ]
    then
      USBNUM=$(dmesg | grep -c "now attached to ttyUSB")
      if [ $USBNUM -eq 0 ] 
      then
        USBNUM=$(ls /dev/usb/tts)
      else
        USBNUM=$(dmesg | grep "now attached to ttyUSB" | tail -n 1)
        USBNUM=${USBNUM#*ttyUSB}
      fi
      eval MASTERDEVICE$I=/dev/usb/tts/$USBNUM
      TEMP=MASTERDEVICE$I
      export MASTERDEVICE=$(eval echo \$$TEMP)
      echo "export MASTERDEVICE $(eval echo \$$TEMP)"
      FRUSBWATCH=$I
    else
# "normal" masters' serial communication device names:
      TEMP=MASTERDEVICE$I
      export MASTERDEVICE=$(eval echo \$$TEMP)
      echo "export MASTERDEVICE $(eval echo \$$TEMP)"
    fi
# number of devices expected to be found as defined in master table:
    export MASTERWRNUM=$((MASTERWRNUM$I))
    echo "export MASTERWRNUM $((MASTERWRNUM$I))"
# sum up the total number of devices expected to be found:
    MASTERWRNUMALL=$(($MASTERWRNUMALL+$((MASTERWRNUM$I))))
# default baudrate for this master (from protocols table)
    export MASTERBAUD=$((MASTERBAUD$I))
    echo "export MASTERBAUD $((MASTERBAUD$I))"
# the power reduction configuration string:
    TEMP=PDELIMIT$I
    export PDELIMIT=$(eval echo \$$TEMP)
    echo "export PDELIMIT $(eval echo \$$TEMP)"
# the additonal configuration string:
    TEMP=MASTERCONFIG$I
    export MASTERCONFIG=$(eval echo \$$TEMP)
    echo "export MASTERCONFIG $(eval echo \$$TEMP)"
# RTPRIO for each master
    if [ $(echo $(eval echo \$$TEMP) | grep -ci RTPRIO) -ne 0 ]
    then
      TEMP2=$(echo $(eval echo \$$TEMP) | tr '/' '\n' | grep RTPRIO)
      TEMP2=${TEMP2#*=}
      eval RTPRIO${I}=$TEMP2
      TEMP=RTPRIO$I
      export RTPRIO=$(eval echo \$$TEMP)
      echo "export RTPRIO $(eval echo \$$TEMP)"
    else
      echo "RTPRIO not set"
    fi
# extended timeout for each master
    if [ $(echo $(eval echo \$$TEMP) | grep -ci EXTENDEDTIMEOUTS) -ne 0 ]
    then
      TEMP2=$(echo $(eval echo \$$TEMP) | tr '/' '\n' | grep EXTENDEDTIMEOUTS)
      TEMP2=${TEMP2#*=}
      eval MASTEREXTENDEDTIMEOUTS${I}=$TEMP2
    else
      eval MASTEREXTENDEDTIMEOUTS${I}=$EXTENDEDTIMEOUTS
    fi
    TEMP=MASTEREXTENDEDTIMEOUTS$I
    export MASTEREXTENDEDTIMEOUTS=$(eval echo \$$TEMP)
    echo "export MASTEREXTENDEDTIMEOUTS $(eval echo \$$TEMP)"
# Meteocontrol Export Configuration:
    MC=$(readFieldFromDB "select format from sending where format=\"mc\"" | grep -c mc)
    if [ $MC -eq 1 ] 
    then
      export MC=1
      echo "export MC 1"
      MCID=$(readFieldFromDB "select id from sending where format=\"mc\"")
      export MCID=$MCID
      echo "export MCID $MCID"
    fi
# set the MSB special ID environment variable:
    TEMP=KILLMASTER$I
    if [ $SWITCH -eq 1 -a $(echo $(eval echo \$$TEMP) | grep -c MSBMasterLinux) -eq 1 ]
    then
      export MSBID=$SWITCH1$SWITCH2
    fi
# only uart0 (/dev/ttyS/1) on iGate needs uart485 to be called:	
    TEMP=MASTERDEVICE$I
    if [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ttyS/1) -eq 1 ]
    then
      TEMP=MASTERUART$I
      echo "set uart485 to $(eval echo \$$TEMP)"
      $UART485 $(eval echo \$$TEMP)
    fi
    # Wago UPS
    TEMP=KILLMASTER$I
    if [ $(echo $(eval echo \$$TEMP) | grep -c WagoUpsMasterLinux) -eq 1 ]
    then
      TEMP=MASTERDEVICE$I
      echo symlinking $(eval echo \$$TEMP) to /dev/wagoUps
      $SUDO ln -s $(eval echo \$$TEMP) /dev/wagoUps
      if [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ttyO1) -eq 1 ]
      then
        echo "set COM1 to RS232 with termination"
        $SUDO /opt/iplon/scripts/onrisctool -p 1 -t rs232 -r
      elif [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ttyO1) -eq 1 ]
      then
        echo "set COM2 to RS232 with termination"
        $SUDO /opt/iplon/scripts/onrisctool -p 2 -t rs232 -r
      fi
      $SUDO systemctl restart nut-driver.service
    # Alekto2 set com mode to RS485 half duplex with Termination
    elif [ $(echo $iplonHW | grep -ci Alekto2) -ne 0 ]
    then
      TEMP=MASTERDEVICE$I
      if [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ttyUSB-1-1.2:1.0) -eq 1 ]
      then
        TEMP=KILLMASTER$I
        if [ $(echo $(eval echo \$$TEMP) | grep -c VirtualMasterLinux) -eq 1 ]
        then
          echo "set COM1 to RS422 with termination"
          $SUDO /opt/iplon/scripts/onrisctool.py -t rs422-term -p 1
        else
	        echo "set COM1 to RS485 half duplex with termination"
          $SUDO /opt/iplon/scripts/onrisctool.py -t rs485-hd-term -p 1
        fi
      elif [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ttyUSB-1-1.2:1.1) -eq 1 ]
      then
        TEMP=KILLMASTER$I
        if [ $(echo $(eval echo \$$TEMP) | grep -c VirtualMasterLinux) -eq 1 ]
        then
          echo "set COM2 to RS422 with termination"
          $SUDO /opt/iplon/scripts/onrisctool.py -t rs422-term -p 2
        else
        	echo "set COM2 to RS485 half duplex with termination"
          $SUDO /opt/iplon/scripts/onrisctool.py -t rs485-hd-term -p 2
        fi
      fi
# setting RS485-HD with termination  /dev/ttyO1 and /dev/ttyO2 (COM1 and COM2) at Baltos
    elif [ $(echo $iplonHW | grep -ci Baltos) -ne 0 ]
    then
      TEMP=MASTERDEVICE$I
      if [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ttyO1) -eq 1 ]
      then
        export SERIALMODE=1
        TEMP=MASTERCONFIG$I
        if [ $(echo $(eval echo \$$TEMP) | grep -c 232) -eq 1 ]
        then
          echo "set COM1 to RS232 with termination"
          $SUDO /opt/iplon/scripts/onrisctool -p 1 -t rs232 -r
        else
          TEMP=KILLMASTER$I
          if [ $(echo $(eval echo \$$TEMP) | grep -c VirtualMasterLinux) -eq 1 ]
          then
            echo "set COM1 to RS422 with termination"
            $SUDO /opt/iplon/scripts/onrisctool -p 1 -t rs422 -r
          else
            echo "set COM1 to RS485 half duplex with termination"
            $SUDO /opt/iplon/scripts/onrisctool -p 1 -t rs485-hd -r
          fi
        fi
      elif [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ttyO2) -eq 1 ]
      then
        export SERIALMODE=1
        TEMP=MASTERCONFIG$I
        if [ $(echo $(eval echo \$$TEMP) | grep -c 232) -eq 1 ]
        then
          echo "set COM2 to RS232 with termination"
          $SUDO /opt/iplon/scripts/onrisctool -p 2 -t rs232 -r
        else
          TEMP=KILLMASTER$I
          if [ $(echo $(eval echo \$$TEMP) | grep -c VirtualMasterLinux) -eq 1 ]
          then
            echo "set COM2 to RS422 with termination"
            $SUDO /opt/iplon/scripts/onrisctool -p 2 -t rs422 -r
          else
            echo "set COM2 to RS485 half duplex with termination"
            $SUDO /opt/iplon/scripts/onrisctool -p 2 -t rs485-hd -r
          fi
        fi
      fi
    fi
  fi
  TEMP=KILLMASTER$I 
# lti fetches its data from the local ftp directory where the inverters
# put them actively:
  if [ $(echo $(eval echo \$$TEMP) | grep -c LtiMasterLinux) -eq 1 ]
  then
    chown lti:lti $PX/mnt/jffs2/lti
    sed -i "s#\#ftpput#ftpput#g" $PX/etc/inetd.conf
  fi
  if [ $(echo $(eval echo \$$TEMP) | grep -c BoschMasterLinux) -eq 1 ]
  then
    eval MASTERPARA${I}="-s\ virtual\ -d\ bosch"
  fi
  if [ $(echo $(eval echo \$$TEMP) | grep -c TaromMasterLinux) -eq 1 ]
  then
    eval MASTERPARA${I}="-s\ virtual\ -d\ tarom"
  fi
  if [ $(echo $(eval echo \$$TEMP) | grep -c WagoUpsMasterLinux) -eq 1 ]
  then
    eval MASTERPARA${I}="-s\ virtual\ -d\ wagoUps"
  fi
# *finally* really start the application:
  echo Starting: $(eval echo \$$TEMP)
  TEMP2=MASTERPARA$I
  echo with parameter: $(eval echo \$$TEMP2)
  echo "export MASTERNAME $(eval echo \$$TEMP)"
  TEMP3=MASTEREXTENDEDTIMEOUTS$I
  if [ "$(echo $(eval echo \$$TEMP3))" != "UNDEFINED" ]
  then
    $(eval echo \$$TEMP) $(eval echo \$$TEMP2) -x $(eval echo \$$TEMP3) &
  else
    $(eval echo \$$TEMP) $(eval echo \$$TEMP2) &
  fi
  eval MASTERPID${I}=$!
  echo "done"
# save the process id for later use: 
 echo $((MASTERPID$I)) > /ram/masterPID$I
  TEMP=MASTERDEVICE$I
# a serial device of /dev/ptmx tells us to start a simulator for this master:
  if [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ptmx) -eq 1 ]
  then
    cd $PX/mnt/jffs2/kacoSimu
    echo Starting: KacoSimu
    ./KacoSimu -s simulator &
  fi
# increment run variable
  I=$(($I+1))
# skip the LonMaster in this turn (why?):
  if [ $I -eq $LONMASTERID ] 
  then
    I=$(($I+1))
  fi
done

# update the sqlite database to show the sum of all master device numbers in the unit table:
if [ $SWITCH2 -eq 9 -a $SWITCH1 -eq 9 -o $SWITCH -eq 1 ]
then
  if [ $(readFieldFromDB "SELECT value from unit where field=\"inverters\"") -ne $((MASTERWRNUMALL)) ]
  then
    $(readFieldFromDB "UPDATE unit set value=$((MASTERWRNUMALL)) where field=\"inverters\"")
  fi
fi

# startup done LED on
if [ $(echo $iplonHW | grep -ci Baltos) -ne 0 ]
then
  $SUDO /opt/iplon/scripts/onrisctool -l app:1
fi

# monitoring of the running system's status
# ----------------------------------------
I=1
while [ 1 -eq 1 ] 
do
# get epoch time (seconds since 1.1.1970):
  TM=$(date +%s)	
# handle the master's main watch file:
  TEMP=TMPFILEMASTER$I
# if the file exists,
  if [ -f $(eval echo \$$TEMP) ]
  then
#   get its file time  
    TMF=$(date -r $(eval echo \$$TEMP) +%s)	#file time since epoch
  else
#   else reset the file time  
    TMF=0
  fi
# and calculate the point in time, when it would time out as
# last change time + timeout interval:
  WERT=$(($((TMOUTMASTER$I)) + $TMF))			#file time + timeout

# WAITMASTER counts how many times the wait timeout has been exceeded:  
  if [ $((WAITMASTER$I)) -le 0 ]   
  then 
    HANGS=Lua
    TEMP=KILLMASTER$I
    if [ $(echo $(eval echo \$$TEMP) | grep -c Master) -eq 1 -a $TM -lt $WERT ]
    then
      TEMP=TMPFILERHAPSODY$I
      if [ -f $(eval echo \$$TEMP) ]
      then
        TMF=$(date -r $(eval echo \$$TEMP) +%s)
      else
        TMF=0
      fi
      WERT=$(($((TMOUTRHAPSODY$I)) + $TMF))
      HANGS=Rhapsody
    fi
    if [ $TM -gt $WERT ]              
    then
      MASTERCRASHS=$(cat $PX/mnt/jffs2/solar/diagnose | grep masterCrashs)
      MASTERCRASHS=${MASTERCRASHS#* }
      TEMP=KILLMASTER$I
      if [ $(echo $(eval echo \$$TEMP) | grep -c Master) -eq 1 -o $(echo $(eval echo \$$TEMP) | grep -c Display) -eq 1 ] 
      then
        CRASHSM=$(($CRASHSM+1))
        MASTERCRASHS=$(($MASTERCRASHS+1))
        $LEDS g 0 > /dev/null
		handleAlarm "Watchdog_$TM" "Master $(eval echo \$$TEMP) with ID $I Crashed" 1 "$(eval echo \$$TEMP) Crashed" "iGate" "crash"
      fi
      MODEMFAILURES=$(cat $PX/mnt/jffs2/solar/diagnose | grep modemFailures)
      UNSENTS=$(cat $PX/mnt/jffs2/solar/diagnose | grep unsents)
      PVHACRASHS=$(cat $PX/mnt/jffs2/solar/diagnose | grep pvhaCrashs)
      PVHACRASHS=${PVHACRASHS#* }
      REBOOTS=$(cat $PX/mnt/jffs2/solar/diagnose | grep reboots)
      SENDINGCRASHS=$(cat $PX/mnt/jffs2/solar/diagnose | grep sendingCrashs)
      SENDINGCRASHS=${SENDINGCRASHS#* }
      if [ $(echo $(eval echo \$$TEMP) | grep -c Sending) -eq 1 ]
      then
        echo unknown > $PX/var/log/curlLogS.log
        echo unknown > $PX/var/log/curlAlarmS.log
        CRASHSS=$(($CRASHSS+1))
        SENDINGCRASHS=$(($SENDINGCRASHS+1))
      fi
      echo "masterCrashs $MASTERCRASHS" > $PX/mnt/jffs2/solar/diagnose
      echo "$MODEMFAILURES" >> $PX/mnt/jffs2/solar/diagnose
      echo "$UNSENTS" >> $PX/mnt/jffs2/solar/diagnose
      echo "pvhaCrashs $PVHACRASHS" >> $PX/mnt/jffs2/solar/diagnose
      echo "$REBOOTS" >> $PX/mnt/jffs2/solar/diagnose
      echo "sendingCrashs $SENDINGCRASHS" >> $PX/mnt/jffs2/solar/diagnose
      echo "Killing process $(eval echo \$$TEMP) ..."
      TEMP2=$(eval echo \$$TEMP)
      #killall -q -9 ${TEMP2#*/}
      kill -9 $((MASTERPID$I)) 2>/dev/null
      echo "done"
      TEMP=MASTERPATH$I
      cd $(eval echo \$$TEMP)
      sleep 10
      TEMP=KILLMASTER$I
      echo "Restarting process $(eval echo \$$TEMP) because $HANGS hangs..."
      if [ $(echo $(eval echo \$$TEMP) | grep -c Master) -eq 1 ]
      then
        export MASTERID=$I
        TEMP=MASTERDEVICE$I
        export MASTERDEVICE=$(eval echo \$$TEMP)
        export MASTERWRNUM=$((MASTERWRNUM$I))
		    export MASTERPORT=$(($I+10500))
    		export MASTERBAUD=$((MASTERBAUD$I))
        TEMP=MASTEREXTENDEDTIMEOUTS$I
        export MASTEREXTENDEDTIMEOUTS=$(eval echo \$$TEMP)
        TEMP=RTPRIO$I
        export RTPRIO=$(eval echo \$$TEMP)
    		TEMP=PDELIMIT$I
	      export PDELIMIT=$(eval echo \$$TEMP)
        TEMP=MASTERCONFIG$I
        export MASTERCONFIG=$(eval echo \$$TEMP)
        TEMP=MASTERDEVICE$I
        if [ $(echo $(eval echo \$$TEMP) | grep -c /dev/ttyS/1) -eq 1 ]
        then
          TEMP=MASTERUART$I
          $UART485 $(eval echo \$$TEMP)
        fi
      fi
      TEMP=KILLMASTER$I
      TEMP2=MASTERPARA$I
      TEMP3=MASTEREXTENDEDTIMEOUTS$I
      if [ "$(echo $(eval echo \$$TEMP3))" != "UNDEFINED" ]
      then
        $(eval echo \$$TEMP) $(eval echo \$$TEMP2) -x $(eval echo \$$TEMP3) &
      else
        $(eval echo \$$TEMP) $(eval echo \$$TEMP2) &
      fi
      eval MASTERPID${I}=$!
      echo "done"
      export MASTERPID=$((MASTERPID$I))
      echo $((MASTERPID$I)) > /ram/masterPID$I
      eval WAITMASTER${I}=18
    else
      TEMP=KILLMASTER$I
      #if [ $(echo $(eval echo \$$TEMP) | grep -c Master) -eq 1 ]
      #then
        #CRASHSM=0
      #fi
      #if [ $(echo $(eval echo \$$TEMP) | grep -c Sending) -eq 1 ]
      #then
        #CRASHSS=0
      #fi
    fi
  else
    eval WAITMASTER${I}=$(($((WAITMASTER$I))-1))
  fi
    
  if [ $I -lt $MASTERS ] 
  then
    I=$(($I+1))
  else
    I=1
  fi

  if [ $I -eq $LONMASTERID ]
  then
    if [ $I -lt $MASTERS ]
    then 
      I=$(($I+1))
    else
      I=1
    fi
  fi

  RDUSED=$($SUDO du -c /tmp /var/run /var/lock /var/log /ram | grep total)
  RDUSED=${RDUSED%total}
  if [ $CRASHSM -le 10 ]
  then
    if [ $CRASHSS -le 10 ]
    then
      if [ $RDUSED -le 40000 ]
      then
        feedwd 
      else
		handleAlarm "Watchdog_$TM" 'Ramdisk to full... stop updating Watchdog' 1 "Ramdisk full... rebooting" iGate linux
        $REBOOT
      fi
    else
	  handleAlarm "Watchdog_$TM" 'Sending Crashs to many... stop updating Watchdog' 2 "Too Many Sending Crashs... rebooting" iGate linux
      $REBOOT
    fi  
  else
    handleAlarm "Watchdog_$TM" 'Master Crashs to many... stop updating Watchdog' 3 "Too Many Master Crashs... rebooting" iGate linux
    $REBOOT
  fi
  sleep 10

# Hardware Watchdog Handling
# --------------------------
# 
# wait until 10 minutes have passed, before taking over watchdog handling:  
  if [ $WDBINKILL -lt 60 ]
# before 10 minutes have passed just increment the counter:  
  then
    WDBINKILL=$(($WDBINKILL+1))
  else	
# afterwards kill the default watchdog feeder:  
# (we must from now on do this ourselves with "feedwd")
    if [ $WDBINKILL -eq 60 ]
    then
      if [ $OSTYPE != "linux-gnueabihf" -a $OSTYPE != "linux-gnu" ]
	  then
# on iGate we set the watchdog to 15 minutes
        /usr/sbin/devmem2 0xa0900174 w 0x95
# then kill the watchdog binary:		
        killall -q -9 watchdog
###	  else
# on debian shutdown the busybox watchdog binary by 
# stopping its service:
###        $SUDO systemctl stop iplon-wd.service
	  fi  
      feedwd
    fi  
  fi

# Fronius USB watching
# --------------------
#
  if [ $FRUSBWATCH -ne 0 ] 
  then
    USBNUMNEW=$(dmesg | grep -c "now attached to ttyUSB")
    if [ $USBNUMNEW -ne 0 ]
    then
      USBNUMNEW=$(dmesg | grep "now attached to ttyUSB" | tail -n 1)
      USBNUMNEW=${USBNUMNEW#*ttyUSB}
      if [ $USBNUM -ne $USBNUMNEW ] 
      then
        USBNUM=$USBNUMNEW
        echo "Found new USB Devicenumber $USBNUM"
        echo "Restarting FroniusMasterLinux!"
        eval MASTERDEVICE$FRUSBWATCH=/dev/usb/tts/$USBNUM
        TEMP=KILLMASTER$FRUSBWATCH
        TEMP2=$(eval echo \$$TEMP)
        #killall -q -9 ${TEMP2#*/}
        kill -9 $((MASTERPID$I)) 2>/dev/null
        TEMP=TMPFILEMASTER$FRUSBWATCH
        rm $(eval echo \$$TEMP)
      fi
    fi
  fi
done
) 2>&1 >> /var/log/iplon/y.log
