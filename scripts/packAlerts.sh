#!/bin/bash

cd $1
tar -cjf $2_ALR_$3.tar.bz2.alr *.alr --exclude=*bz2* 2>/dev/null
FILELIST=$(tar -jtf $2_ALR_$3.tar.bz2.alr)
FILES=$(echo $FILELIST | grep -c alr)
I=1

if [ $FILES -eq 0 ] 
then
  rm $2_ALR_$3.tar.bz2.alr
else
  while [ $I -ne $(($FILES+1)) ]
  do
    FILE=$(echo $FILELIST | head -n $I | tail -n 1)
    I=$(($I+1))
    rm $FILE
  done
fi
