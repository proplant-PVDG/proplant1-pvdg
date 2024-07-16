#!/bin/bash
IPLONHW=$(cat /etc/iplonHW)
if [ -e /flash.baltos -a $(echo $IPLONHW | grep -ci NUC) -ne 0 ]
then
  fdisk /dev/sda -l
  read -p "do you really want to flash /dev/sda, all data will be lost! y/n: " YES
  if [ "$YES" != "y" ]
  then
    echo aborting flashing
    exit
  fi
  #systemctl stop iplon-bl.service
  mkdir /mnt/rootfs
  mount /dev/sda1 /mnt/rootfs
  BACKUP=0
  if [ $(mountpoint /mnt/rootfs | grep -ci "is a mountpoint") -eq 1 ]
  then
    echo backuping old config and files...
    BACKUP=1
    mkdir /tmp/backup
    cp -p /mnt/rootfs/opt/iplon/db/iPLON.sqlite /tmp/backup
    cp -p /mnt/rootfs/opt/iplon/jffs2/htdocs/*.unsent /tmp/backup
    cp -p /mnt/rootfs/opt/iplon/jffs2/htdocs/*.csv /tmp/backup
    cp -p /mnt/rootfs/opt/iplon/jffs2/sending/*.alr /tmp/backup
    cp -p /mnt/rootfs/opt/iplon/jffs2/sending/*.mail /tmp/backup
    cp -p /mnt/rootfs/opt/iplon/jffs2/sending/*.sqlite /tmp/backup
    cp -p /mnt/rootfs/opt/iplon/jffs2/oldEValues/*.txt /tmp/backup
    umount /mnt/rootfs
  fi
  echo create 4GB partition
  dd if=/dev/zero of=/dev/sda bs=1M count=10
  (echo n; echo p; echo; echo; echo +3787776K; echo a; echo w) | fdisk /dev/sda
  echo make btrfs filesystem
  mkfs.btrfs /dev/sda1 -L NUC -f
  mount /dev/sda1 /mnt/rootfs
  echo copy rootfs...
  rsync -aAX --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/rootfs/*","/media/*","/lost+found","/ram/*","/var/log/*"} /* /mnt/rootfs
  mkdir -p /mnt/rootfs/dev
  mkdir -p /mnt/rootfs/proc
  mkdir -p /mnt/rootfs/sys
  mkdir -p /mnt/rootfs/tmp
  mkdir -p /mnt/rootfs/run
  mkdir -p /mnt/rootfs/media
  mkdir -p /mnt/rootfs/lost+found
  mkdir -p /mnt/rootfs/ram
  mkdir -p /mnt/rootfs/var/log
  rm /mnt/rootfs/flash.baltos
  echo "debugfs /sys/kernel/debug debugfs defaults                    0       0" > /mnt/rootfs/etc/fstab
  echo "tmpfs   /var/log          tmpfs   defaults,size=51200k        0       0" >> /mnt/rootfs/etc/fstab
  echo "tmpfs   /ram              tmpfs   defaults,size=51200k        0       0" >> /mnt/rootfs/etc/fstab
  echo "tmpfs   /tmp              tmpfs   defaults,size=51200k        0       0" >> /mnt/rootfs/etc/fstab
  rm /mnt/rootfs/etc/udev/rules.d/70-persistent-net.rules
  if [ $BACKUP -eq 1 ]
  then
    echo restoring old config and files...
    cp /tmp/backup/iPLON.sqlite /mnt/rootfs/opt/iplon/db/iPLON.sqlite
    cp /tmp/backup/*.unsent /mnt/rootfs/opt/iplon/jffs2/htdocs
    cp /tmp/backup/*.csv /mnt/rootfs/opt/iplon/jffs2/htdocs
    cp /tmp/backup/*.alr /mnt/rootfs/opt/iplon/jffs2/sending
    cp /tmp/backup/*.sqlite /mnt/rootfs/opt/iplon/jffs2/sending
    cp /tmp/backup/*.mail /mnt/rootfs/opt/iplon/jffs2/sending
    cp /tmp/backup/*.txt /mnt/rootfs/opt/iplon/jffs2/oldEValues
    ls -l /tmp/backup >> /mnt/rootfs/backup.log
  fi
  echo installing grub to /dev/sda
  mount -o bind /dev /mnt/rootfs/dev 
  mount -o bind /sys /mnt/rootfs/sys 
  mount -t proc /proc /mnt/rootfs/proc 
  chroot /mnt/rootfs grub-install /dev/sda
  chroot /mnt/rootfs update-grub
  sed -i "s# ro # rw #g" /mnt/rootfs/boot/grub/grub.cfg
  echo syncing...
  sync
  umount /mnt/rootfs
  echo done
  echo halt device with \"halt -p\", remove usb stick and reboot
elif [ -e /flash.baltos -a $(/opt/iplon/scripts/onrisctool -q | grep -ci on) -eq 0 ]
then
  mkdir /mnt/kernel
  mkdir /mnt/rootfs

  echo backuping old config and files if exists...
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  ubiattach -p /dev/mtd5
  mount -t ubifs ubi0:rootfs /mnt/rootfs
  BACKUP=0
  if [ $(mountpoint /mnt/rootfs | grep -ci "is a mountpoint") -eq 1 ]
  then
    echo backuping old config and files...
    BACKUP=1
    mkdir /tmp/backup
    cp /mnt/rootfs/opt/iplon/db/iPLON.sqlite /tmp/backup
    cp /mnt/rootfs/opt/iplon/jffs2/htdocs/*.unsent /tmp/backup
    cp /mnt/rootfs/opt/iplon/jffs2/htdocs/*.csv /tmp/backup
    cp /mnt/rootfs/opt/iplon/jffs2/sending/*.alr /tmp/backup
    cp /mnt/rootfs/opt/iplon/jffs2/sending/*.mail /tmp/backup
    cp /mnt/rootfs/opt/iplon/jffs2/sending/*.sqlite /tmp/backup
    cp /mnt/rootfs/opt/iplon/jffs2/oldEValues/*.txt /tmp/backup
    umount /mnt/rootfs
  fi
  ubidetach -p /dev/mtd5

  echo stopping services...
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  systemctl stop iplon-bl.service
  /bin/busybox watchdog /dev/watchdog

  echo copy barebox...
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0

  mount /dev/mmcblk0p1 /boot/uboot
  cat /boot/uboot/MLO > /dev/mtdblock0
  cat /boot/uboot/barebox.bin > /dev/mtdblock4

  echo creating flash partitions...
  ubiformat -y /dev/mtd5 &
  PID=$!
  while [ -e /proc/$PID ]
  do
    /opt/iplon/scripts/onrisctool -l app:1
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:0
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:1
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:0
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:1
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:0
    sleep 1
  done
  ubiattach -p /dev/mtd5
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0

  ubimkvol /dev/ubi0 -N kernel -s 10MiB
  ubimkvol /dev/ubi0 -N rootfs -s 230MiB
  mount -t ubifs ubi0:kernel /mnt/kernel
  mount -t ubifs ubi0:rootfs /mnt/rootfs

  echo copy kernel...
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:1
  sleep 0.1
  /opt/iplon/scripts/onrisctool -l app:0

  cp /boot/uboot/kernel-fit.itb /mnt/kernel
  umount /mnt/kernel

  echo copy rootfs...
  rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/kernel/*","/mnt/rootfs/*","/media/*","/lost+found","/boot/*","/ram/*","/var/log/*"} /* /mnt/rootfs &
  PID=$!
  while [ -e /proc/$PID ]
  do
    /opt/iplon/scripts/onrisctool -l app:1
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:0
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:1
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:0
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:1
    sleep 0.1
    /opt/iplon/scripts/onrisctool -l app:0
    sleep 1
  done
  mkdir -p /mnt/rootfs/dev
  mkdir -p /mnt/rootfs/proc
  mkdir -p /mnt/rootfs/sys
  mkdir -p /mnt/rootfs/tmp
  mkdir -p /mnt/rootfs/run
  mkdir -p /mnt/rootfs/media
  mkdir -p /mnt/rootfs/lost+found
  mkdir -p /mnt/rootfs/boot
  mkdir -p /mnt/rootfs/ram
  mkdir -p /mnt/rootfs/var/log
  rm /mnt/rootfs/flash.baltos
  echo "debugfs /sys/kernel/debug debugfs defaults                    0       0" > /mnt/rootfs/etc/fstab
  echo "tmpfs   /var/log          tmpfs   defaults,size=51200k        0       0" >> /mnt/rootfs/etc/fstab
  echo "tmpfs   /ram              tmpfs   defaults,size=51200k        0       0" >> /mnt/rootfs/etc/fstab
  echo "tmpfs   /tmp              tmpfs   defaults,size=51200k        0       0" >> /mnt/rootfs/etc/fstab
  rm /mnt/rootfs/etc/udev/rules.d/70-persistent-net.rules
  echo \#\!/bin/sh -e > /mnt/rootfs/etc/rc.local
  echo "#/opt/iplon/scripts/iplonFlasher.sh &" >> /mnt/rootfs/etc/rc.local
  echo "exit 0" >> /mnt/rootfs/etc/rc.local
  touch -t 197001010000 /mnt/rootfs/etc/rc.local
  chmod a+x /mnt/rootfs/etc/rc.local
  if [ $BACKUP -eq 1 ]
  then
    echo restoring old config and files...
    cp /tmp/backup/iPLON.sqlite /mnt/rootfs/opt/iplon/db/iPLON.sqlite
    cp /tmp/backup/*.unsent /mnt/rootfs/opt/iplon/jffs2/htdocs
    cp /tmp/backup/*.csv /mnt/rootfs/opt/iplon/jffs2/htdocs
    cp /tmp/backup/*.alr /mnt/rootfs/opt/iplon/jffs2/sending
    cp /tmp/backup/*.sqlite /mnt/rootfs/opt/iplon/jffs2/sending
    cp /tmp/backup/*.mail /mnt/rootfs/opt/iplon/jffs2/sending
    cp /tmp/backup/*.txt /mnt/rootfs/opt/iplon/jffs2/oldEValues
    ls -l /tmp/backup >> /mnt/rootfs/backup.log
  fi
  umount /mnt/rootfs
  umount /boot/uboot
  echo done
  echo remove sdcard and restart device!
  /opt/iplon/scripts/onrisctool -l app:1
fi
