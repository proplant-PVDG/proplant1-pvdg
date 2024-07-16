#!/bin/bash

if [ "$4" == "acteno" ]
then
  cd $1
  UNSENT=$(ls *.tar.bz2.unsent -ABrt1 | tail -1)
  if [ -z "$UNSENT" ]
  then
    tar --remove-files -cjf $2_ALL_$3.tar.bz2.unsent *.csv.unsent --exclude=*bz2* 2>/dev/null
  else
    bunzip2 $UNSENT 2>/dev/null
    tar --remove-files -rf $UNSENT.out *.csv.unsent --exclude=*bz2* 2>/dev/null
    bzip2 $UNSENT.out
    mv $UNSENT.out.bz2 $UNSENT
  fi
else 
  cd $1
  find . -name '*.csv.unsent' ! -name '*bz2*' > filesToTar.txt
  tar --remove-files -cjf $2_ALL_$3.tar.bz2.unsent -T filesToTar.txt
  rm filesToTar.txt
fi
