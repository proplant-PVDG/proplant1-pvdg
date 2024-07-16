#!/bin/sh

SRCPATH="/mnt/jffs2/solar/persistence"
DSTPATH="/mnt/jffs2/solar/persistence_back"
CHECKSUM="CS:NONE:CS"
LOG="/mnt/jffs2/log/y.log"

if [ ! -d $DSTPATH ]
then
        mkdir -p $DSTPATH
fi
if [ ! -d $SRCPATH ]
then
        mkdir -p $SRCPATH
fi

if [ "$1" = "restore" ]
then
        cd $SRCPATH
        sed -i 's/inf/0/' *
        sed -i "1s/.*/$CHECKSUM/" *
        cd $DSTPATH
        for f in *
        do
                if [ -s $f ]
                then
                        if [ ! -s $SRCPATH/$f ]
                        then
                                echo "File $f crashed restoring from backup at $(date)"
                                echo "File $f crashed restoring from backup at $(date)" >> $LOG
                                cp $f $SRCPATH
                        fi
                fi
        done
else
        cd $SRCPATH
        sed -i 's/inf/0/' *
        sed -i "1s/.*/$CHECKSUM/" *
        for f in *
        do
                if [ -s $f ]
                then
                        cp $f $DSTPATH
                        echo "File $f backup at $(date)"
                fi
        done
        cd $DSTPATH
        if [ $(ls | grep .tmp | wc -l) -gt 0 ]
        then
                rm *.tmp
        fi
        sed -i 's/inf/0/' *
        sed -i "1s/.*/$CHECKSUM/" *
fi

