#!/bin/bash

if [ $(echo $ID_MODEL | grep -c USB_to_RS-422_485_Adapter) -eq 1 -o $(echo $ID_MODEL | grep -c Dual_RS232) -eq 1 ];
then
 D="/dev/ttyUSB-$(echo $DEVPATH | sed 's|.*/\(1[^/]*\)/tty.*|\1|')"
 case "$ACTION" in
   "add")
     ln -s $DEVNAME $D
     echo "added $D at $(date)" >> /opt/iplon/log/y.log
   ;;
   "remove")
     rm -f  $D
     echo "removed $D at $(date)" >> /opt/iplon/log/y.log
   ;;
  esac
fi
