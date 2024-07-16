#!/bin/sh
wget -q -O - http://checkip.dyndns.org:80|sed -e 's/.*Current IP Address: //' -e 's/<.*$//'
