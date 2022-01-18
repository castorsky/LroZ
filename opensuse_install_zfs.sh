#!/bin/sh
## by LordNicky

. ./opensuse_install_zfs.conf

printf "${GREEN}Hi! This script will help you to install OpenSUSE
with using zfs filesystem.
${ORANGE}You need a working network before we will start.
Also you need to start this script as root.
And finally you must to set a preferred values
for variables in opensuse_install_zfs.conf!
Please check, that all .sh files
of installation scripts are executables. 
${GREEN}If you want continue by ssh,
you need install openssh-server, enable pass and start service:
${PURPLE}sudo zypper in -y openssh-server
sudo systemctl restart sshd.service
sudo passwd
${ORANGE}Please, accept new keys for repos during installation (a).
${GREEN}Proceed installation? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

if whoami | grep -q "root";
then :;
else printf "${RED}You must run script as root! Exiting.${NC}\n"; exit 1;
fi

printf "${BLUE}Initial cleaning...${NC}\n";
rm -f /etc/zypp/repos.d/filesystems.repo;

printf "${BLUE}Adding and refreshing repository...${NC}\n";
if zypper addrepo "https://download.opensuse.org/repositories/filesystems/$(lsb-release -rs)/filesystems.repo";
then if zypper refresh;
     then :;
     else printf "${RED}ERROR: Refresh repositories.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Add repository.${NC}\n"; exit 1;
fi

## Disable automounting
gsettings set org.gnome.desktop.media-handling automount false;

printf "${BLUE}Installing additional packages...${NC}\n";
if zypper install -y zfs zfs-kmp-default gdisk dkms;
then if modprobe zfs;
     then :;
     else printf "${RED}ERROR: Add kernel module.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Install packages.${NC}\n"; exit 1;
fi

printf "${GREEN}You need to clean disk manually, if it used in a MD array.
Proceed installation? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac
printf "${BLUE}Cleaning partitions...${NC}\n";
a=0;
while [ "$a" -lt "$DISK_NUM" ]
do	
  eval sgdisk --zap-all '$DISK_'$a;
  a=$((a+1));
done

printf "${BLUE}Partitioning your disk(s)...${NC}\n";
b=0;
while [ "$b" -lt "$DISK_NUM" ]
do
  if [ "$BOOT_TYPE" -eq 1 ]
  then eval sgdisk -a1 -n1:24K:+1000K -t1:EF02 '$DISK'_$b;
  elif [ "$BOOT_TYPE" -eq 2 ]
  then eval sgdisk -a1 -n1:1M:+512M -t1:EF00 '$DISK'_$b;
  else printf "${RED}ERROR: Set correct ${CYAN}BOOT_TYPE${RED}!${NC}\n";
  fi
  eval sgdisk -n2:0:+1G -t2:BF01 '$DISK'_$b;
  if [ -z "$ROOTSIZE" ];
  then eval sgdisk -n3:0:0 -t3:BF00 '$DISK'_$b;
  else eval sgdisk -n3:0:+"$ROOTSIZE" -t3:BF00 '$DISK'_$b;
  fi
  b=$((b+1));
done

printf "${GREEN}Please, check partitioning validity:${NC}\n";
c=0;
while [ "$c" -lt "$DISK_NUM" ]
do	
  eval sgdisk --print '$DISK_'$c;
  c=$((c+1));
done
printf "${GREEN}Partition table(s) look right? Proceed? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

printf "${BLUE}Creating boot pool.${NC}\n";
d=0;
bpool_parts="";
while [ "$d" -lt "$DISK_NUM" ]
do	
  eval bp_part='$DISK_'$d-part2;
  bpool_parts="$bpool_parts $bp_part";
  d=$((d+1));
done
eval zpool create "$BPOOL_OPT" -R /mnt bpool "$ZPOOL_TYPE" "$bpool_parts";

printf "${BLUE}Creating root pool...${NC}\n"
e=0;
rpool_parts="";
while [ "$e" -lt "$DISK_NUM" ]
do	
  eval rp_part='$DISK_'$e-part3;
  rpool_parts="$rpool_parts $rp_part";
  e=$((e+1));
done
eval zpool create "$RPOOL_OPT" -R /mnt rpool "$ZPOOL_TYPE" "$rpool_parts";

printf "${GREEN}Please, check pools validity:${NC}\n";
zpool status;
printf "${GREEN}ZFS pool(s) look right? Proceed? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

printf "${BLUE}Creating filesystems...${NC}\n";
zfs create -o canmount=off -o mountpoint=none rpool/ROOT;
zfs create -o canmount=off -o mountpoint=none bpool/BOOT;
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/suse;
zfs mount rpool/ROOT/suse;
zfs create -o mountpoint=/boot bpool/BOOT/suse;
zfs create rpool/home;
zfs create -o mountpoint=/root rpool/home/root;
chmod 700 /mnt/root;
zfs create -o canmount=off rpool/var;
zfs create -o canmount=off rpool/var/lib;
zfs create rpool/var/log;
zfs create rpool/var/spool;
if [ "$ZFS_CACHE" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  rpool/var/cache;
else :;
fi	
if [ "$ZFS_VARTMP" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  rpool/var/tmp;
     chmod 1777 /mnt/var/tmp;
else :;
fi
if [ "$ZFS_OPT" -eq 1 ]
then zfs create rpool/opt;
else :;
fi
if [ "$ZFS_SRV" -eq 1 ]
then zfs create rpool/srv;
else :;
fi
if [ "$ZFS_LOCAL" -eq 1 ]
then zfs create -o canmount=off rpool/usr;
     zfs create rpool/usr/local;
else :;
fi
if [ "$ZFS_GAMES" -eq 1 ]
then zfs create rpool/var/games;
else :;
fi
if [ "$ZFS_MAIL" -eq 1 ]
then zfs create rpool/var/mail;
else :;
fi
if [ "$ZFS_SNAP" -eq 1 ]
then zfs create rpool/var/snap;
else :;
fi
if [ "$ZFS_WWW" -eq 1 ]
then zfs create rpool/var/www;
else :;
fi
if [ "$ZFS_FLAT" -eq 1 ]
then zfs create rpool/var/lib/flatpak;
else :;
fi
if [ "$ZFS_GNOME" -eq 1 ]
then zfs create rpool/var/lib/AccountsService;
else :;
fi
if [ "$ZFS_DOCKER" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  rpool/var/lib/docker;
else :;
fi
if [ "$ZFS_NFS" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  rpool/var/lib/nfs;
else :;
fi
mkdir /mnt/run;
mount -t tmpfs tmpfs /mnt/run;
mkdir /mnt/run/lock;
if [ "$ZFS_TMP" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  rpool/tmp;
     chmod 1777 /mnt/tmp;
else :;
fi
mkdir /mnt/etc/zfs -p;
cp /etc/zfs/zpool.cache /mnt/etc/zfs/;

printf "${GREEN}Please, check created filesystems:${NC}\n";
zfs list;
printf "${GREEN}ZFS filesystems look right? Proceed? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

printf "${BLUE}Installing System...${NC}\n";
if zypper --root /mnt ar "http://download.opensuse.org/distribution/leap/$(lsb-release -rs)/repo/non-oss" non-os;
then :;
else printf "${RED}ERROR: Can't add repository non-os to the new system.${NC}\n"; exit 1;
fi
if zypper --root /mnt ar "http://download.opensuse.org/distribution/leap/$(lsb-release -rs)/repo/oss" os;
then :;
else printf "${RED}ERROR: Can't add repository non-os to the new system.${NC}\n"; exit 1;
fi
if zypper --root /mnt ar "http://download.opensuse.org/update/leap/$(lsb-release -rs)/oss" update-os;
then :;
else printf "${RED}ERROR: Can't add repository non-os to the new system.${NC}\n"; exit 1;
fi
if zypper --root /mnt ar "http://download.opensuse.org/update/leap/$(lsb-release -rs)/non-oss" update-nonos;
then :;
else printf "${RED}ERROR: Can't add repository non-os to the new system.${NC}\n"; exit 1;
fi
zypper --root /mnt refresh;
if [ "$INSTALL_TYPE" -eq 1 ]
then if zypper --root /mnt install -y -t pattern base;
     then :;
     else printf "${RED}ERROR: Can't install base.${NC}\n"; exit 1;
     fi
elif [ "$INSTALL_TYPE" -eq 2 ]
then if zypper --root /mnt install -y -t pattern enhanced_base;
     then :;
     else printf "${RED}ERROR: Can't install base.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Check ${CYAN}INSTALL_TYPE${RED} variable.${NC}\n"; exit 1;
fi
if zypper --root /mnt install -y zypper;
then :;
else printf "${RED}ERROR: Can't install zypper.${NC}\n"; exit 1;
fi
if [ -z "$INSTALL_YAST" ];
then :;
else 
     if zypper --root /mnt install -y yast2;
     then :;
     else printf "${RED}ERROR: Can't install yast2.${NC}\n"; exit 1;
     fi
     if zypper --root /mnt install -y -t pattern "$INSTALL_YAST";
     then :;
     else printf "${RED}ERROR: Can't install $INSTALL_YAST .${NC}\n"; exit 1;
     fi
fi     

printf "${BLUE}Confuguring System...${NC}\n";
printf "$HOST_NAME" > /mnt/etc/hostname;
printf "127.0.1.1	$HOST_FQDN $HOST_NAME" >> /mnt/etc/hosts;
rm /mnt/etc/resolv.conf;
cp /etc/resolv.conf /mnt/etc/;
mount --rbind /dev  /mnt/dev;
mount --rbind /proc /mnt/proc;
mount --rbind /sys  /mnt/sys;
mount -t tmpfs tmpfs /mnt/run;
mkdir /mnt/run/lock;

printf "${GREEN}Now, we need chroot and make some final configurations. 
Proceed? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

mkdir /mnt/root/install;
cp -t /mnt/root/install ./opensuse_install_zfs_chroot/*;
cp -t /mnt/root/install ./opensuse_install_zfs.conf;
if chroot /mnt /usr/bin/env /root/install/opensuse_install_zfs_chroot.sh;
then echo "${BLUE}Leave chroot environment...";
else chroot /mnt /usr/bin/env bash --login;
fi

printf "${BLUE}Unmounting and exporting zpools...${NC}\n";
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {};
zpool export -a;

printf "${ORANGE}After boot to the new installed System,
to do some after-installation steps, run:
/root/install/opensuse_install_zfs_firstboot.sh${NC}\n";

printf "${GREEN}Do you want to reboot, now? (y/n)
y - for reboot
n - for exit to shell${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, rebooting...
	Don't forget to detach installation disk!${NC}\n";
	sleep 5; reboot; exit 0;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac
