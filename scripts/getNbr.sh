#!/bin/bash
# read imsi from umts stick
TEMPFILE=$(mktemp)
chmod ugo+rw $TEMPFILE
if [ $(cat /etc/iplonHW | grep -ci Alekto2) -ne 0 ]
then
  echo $(wvdial imsi 2>&1 | head -n 6 | tail -n 1) > $TEMPFILE
else
  echo $(wvdial imsi 2>&1 | head -n 5 | tail -n 1) > $TEMPFILE
fi
mv -f $TEMPFILE /ram/imsi.txt

# card id currently cannot be read from sticks:
TEMPFILE=$(mktemp)
chmod ugo+rw $TEMPFILE
echo "unknown" > $TEMPFILE
mv -f $TEMPFILE /ram/scid.txt
