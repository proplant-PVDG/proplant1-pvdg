#!/bin/sh
MASTERCRASHS=`cat /mnt/jffs2/solar/diagnose | grep masterCrashs`
MODEMFAILURES=`cat /mnt/jffs2/solar/diagnose | grep modemFailures`
UNSENTS=`cat /mnt/jffs2/solar/diagnose | grep unsents`
UNSENTS=${UNSENTS#* }
UNSENTS=$(($UNSENTS+1))
PVHACRASHS=`cat /mnt/jffs2/solar/diagnose | grep pvhaCrashs`
REBOOTS=`cat /mnt/jffs2/solar/diagnose | grep reboots`
SENDINGCRASHS=`cat /mnt/jffs2/solar/diagnose | grep sendingCrashs`
echo "$MASTERCRASHS" > /mnt/jffs2/solar/diagnose
echo "$MODEMFAILURES" >> /mnt/jffs2/solar/diagnose
echo "unsents $UNSENTS" >> /mnt/jffs2/solar/diagnose
echo "$PVHACRASHS" >> /mnt/jffs2/solar/diagnose
echo "$REBOOTS" >> /mnt/jffs2/solar/diagnose
echo "$SENDINGCRASHS" >> /mnt/jffs2/solar/diagnose
