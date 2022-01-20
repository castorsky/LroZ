#!/bin/bash
rm -f /etc/zfs/zpool.cache;
touch /etc/zfs/zpool.cache;
chmod a-w /etc/zfs/zpool.cache;
chattr +i /etc/zfs/zpool.cache;
for directory in /lib/modules/*; 
do
  kernel_version=$(basename $directory);
  dracut --force --kver $kernel_version;
done
