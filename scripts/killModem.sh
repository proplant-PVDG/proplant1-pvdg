#!/bin/bash
if [ $(cat /etc/iplonHW | grep -ci BBB) -ne 0 ]
then
  devmemiplon 0x47401c60 b 0x00
  bash -c "sleep 1 && echo killModem.sh > /dev/null"
  echo "usb1" > /sys/bus/usb/drivers/usb/unbind
  bash -c "sleep 20 && echo killModem.sh > /dev/null"
  echo "usb1" > /sys/bus/usb/drivers/usb/bind
  bash -c "sleep 1 && echo killModem.sh > /dev/null"
  devmemiplon 0x47401c60 b 0x01
  bash -c "sleep $1 && echo killModem.sh RESET > /dev/null"
else
  pkill -x wvdial --signal 9
  bash -c "sleep 1 && echo killModem.sh > /dev/null"
  wvdial disconnect
  bash -c "sleep 1 && echo killModem.sh > /dev/null"
  wvdial +++
  bash -c "sleep 1 && echo killModem.sh > /dev/null"
  wvdial connect
  bash -c "sleep 5 && echo killModem.sh > /dev/null"
  if [ $(cat /etc/iplonHW | grep -ci Baltos) -ne 0 ]
  then
    MODEL=$(/opt/iplon/scripts/onrisctool -s | grep -i model)
    if [ $(echo $MODEL | grep -ci 212) -ne 0 ] # Baltos iR2110
    then
      if [ $(cat /ram/modemSerial | grep -ci yes) -eq 1 ]
      then
        killall -9 gsmMuxd
        /opt/iplon/scripts/onrisctool -p 1 -t rs232 -r
        bash -c "sleep 5 && echo killModem.sh > /dev/null"
        stty -F /dev/ttyO1 hupcl
        bash -c "sleep 5 && echo killModem.sh > /dev/null"
        stty -F /dev/ttyO1 -hupcl
        bash -c "sleep 5 && echo killModem.sh > /dev/null"
        /opt/iplon/scripts/gsmMuxd -r -p /dev/ttyO1 -b 57600 -w -m mc35 -n -s /dev/mux /dev/ptmx /dev/ptmx /dev/ptmx &
        bash -c "sleep 30 && echo killModem.sh > /dev/null"
      else
        bash -c "sleep 5 && echo killModem.sh > /dev/null"
        rmmod musb_dsps
        bash -c "sleep 5 && echo killModem.sh > /dev/null"
        modprobe musb_dsps
        bash -c "sleep 30 && echo killModem.sh > /dev/null"
      fi
    else
      wvdial uc20reset
      bash -c "sleep 5 && echo killModem.sh > /dev/null"
      /opt/iplon/scripts/onrisctool -k 0
      bash -c "sleep 5 && echo killModem.sh > /dev/null"
      /opt/iplon/scripts/onrisctool -k 1
      bash -c "sleep 30 && echo killModem.sh > /dev/null"
      rmmod musb_dsps
      bash -c "sleep 5 && echo killModem.sh > /dev/null"
      modprobe musb_dsps
      bash -c "sleep 30 && echo killModem.sh > /dev/null"
    fi
  fi
fi

if [ -e /dev/ttyGSM0 ]
then
  rm -f /dev/modemPPP
  rm -f /dev/modemAT
  ln -s /dev/ttyGSM3 /dev/modemPPP
  ln -s /dev/ttyGSM2 /dev/modemAT
  wvdial uc20gps
elif [ -e /dev/ttySTICK0 ]
then
  rm -f /dev/modemPPP
  rm -f /dev/modemAT
  ln -s /dev/ttySTICK0 /dev/modemPPP
  ln -s /dev/ttySTICK2 /dev/modemAT
elif [ $(/opt/iplon/scripts/onrisctool -s | grep -ci 'Model: 212') -eq 1 ]
then
  rm -f /dev/modemPPP
  rm -f /dev/modemAT
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
