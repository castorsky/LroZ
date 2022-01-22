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
./lroz.sh

**Thanx:**

files/genhostid.sh script taken from [openzfs project](https://github.com/openzfs/zfs/files/4537537/genhostid.sh.gz)
