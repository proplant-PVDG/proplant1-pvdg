#!/bin/bash

SQ=$(wvdial sq 2>&1 | grep "+CSQ:" | awk '{print $2}')
REGISTERED=$(wvdial reg 2>&1 | grep -c "+CREG: 0,5")
TEMPFILE=$(mktemp)
chmod ugo+rw $TEMPFILE
echo -n $REGISTERED > $TEMPFILE
echo -n ',' >> $TEMPFILE
echo -n $SQ >> $TEMPFILE
mv -f $TEMPFILE /ram/sq.txt

