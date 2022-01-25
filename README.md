# Linux root on ZFS
Shell scripts, thats can help to install you preffered linux OS on zfs root.
Can be run in silent and semi-interactive mode.

**Tested on:**
- OpenSUSE Leap 15.3
- OpenSUSE Tumbleweed

**To use scripts you need:**
1. Create bootable Live cd or usb with preffered(legacy or UEFI) load interface.
2. Boot from this Live iso and setup network connection. (by "ip" commands, for example)
3. Download zip archive of LroZ scripts and unzip them:
```
wget https://github.com/ndruba/LroZ/archive/refs/heads/master.zip
unzip master.zip
cd ./LroZ
```
4. Edit config:
```
vim lroz.conf
```
or
```
nano lroz.conf
```
5. Run setup:
```
./lroz.sh
```
**Notes:**

To use this scripts you need to have at least a general idea about working of ZFS. [Admin Documentation](https://openzfs.github.io/openzfs-docs/Project%20and%20Community/Admin%20Documentation.html)

[zpool features grub2 compability list](https://github.com/openzfs/zfs/blob/master/cmd/zpool/compatibility.d/grub2)

Installed system may not have the same disk id's list, like Live iso.
If you choose UEFI type of bootloader and system can't boot after installation, 
check that new system have disk id that you choosed during installation.
Otherwise, fix /etc/fstab in new system or repeat installation with correct disk id.

**Thanx:**

files/genhostid.sh script taken from [openzfs project](https://github.com/openzfs/zfs/files/4537537/genhostid.sh.gz)
