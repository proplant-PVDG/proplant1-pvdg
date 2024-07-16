#!/bin/bash
read -p "Do you really want to delte mtd0 till mtd4? y/n: " YES
if [ "$YES" != "y" ]
then
  echo aborting flashing
  exit
fi
dd if=/dev/zero of=/dev/mtd0
dd if=/dev/zero of=/dev/mtd1
dd if=/dev/zero of=/dev/mtd2
dd if=/dev/zero of=/dev/mtd3
dd if=/dev/zero of=/dev/mtd4
