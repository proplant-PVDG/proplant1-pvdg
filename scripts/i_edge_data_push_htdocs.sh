#/bin/sh
sleep 20;
#set -x
current_time=$(date +%s)

export iGate_ID=$(/usr/sbin/sqlite3 -list /var/spool/db "SELECT value from unit where field=\"id\"")
export Cloud_IP=$(/usr/sbin/sqlite3 -list /var/spool/db "SELECT value from unit where field=\"server\"")

RETRY=2
COUNT=0
DATADIR="/mnt/jffs2/htdocs/"
cd $DATADIR
tar -cjf ${iGate_ID}_ALL_$current_time.tar.bz2.unsent *.csv.unsent

FILELIST=$(tar -jtf ${iGate_ID}_ALL_$current_time.tar.bz2.unsent)
FILES=$(echo $FILELIST | grep -c csv)
I=1

if [ $FILES -eq 0 ]
then
  rm ${iGate_ID}_ALL_$current_time.tar.bz2.unsent
else
  while [ $I -ne $(($FILES+1)) ]
  do
    FILE=$(echo $FILELIST | head -n $I | tail -n 1)
    I=$(($I+1))
    rm $FILE
  done
fi

if [ $(ps aux | grep -c $0) -gt 15 ]
then
  echo "$0 Script already running exit now"
  exit 0;
fi

for f in *.tar.bz2.unsent
do
  echo $(date)" Sending $f file..."
  if [ -f $f ]; then
    while [ $COUNT -lt $RETRY ];
    do
      if [ $(/usr/sbin/curl -F file=@$DATADIR$f http://$Cloud_IP/get_data.php?anl_id=$(cat /ram/ali.txt) -s --max-time 180 | grep -c "Originalname") -eq 1 ];
      then
        echo "$0 sending $f success"
        mv $f `echo $f | sed 's/unsent/backup/'`
        break
      else
        echo "$0 sending $f failed"
        COUNT=$(($COUNT+1))
      fi
    done
    COUNT=0
  fi
done
