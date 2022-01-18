#!/bin/sh
## by LordNicky

. /root/install/opensuse_install_zfs.conf

cache_pool_function () {
a=0;
while [ "$a" -lt 4 ]
do	 
  if [ $a -lt 1 ] 
  then printf "${GREEN}Do you see all $1 filesystems?${NC}\n";
  else printf "${GREEN}And now?${NC}\n";
  fi
  cat "/etc/zfs/zfs-list.cache/$1";
  read -r user_reply;
  case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	break;; 
	n|N) if [ $a -eq 3 ]
	     then printf "${ORANGE}You need manually check cache creating.
	     After resolving cache problem, run script again by:
             ${PURPLE}/root/install/opensuse_install_zfs_chroot.sh 2${NC}\n";
	     pkill zed; exit 1;
	     else zfs set "canmount=$2" "$1/BOOT/suse"; sleep 10;
	     fi 
	     ;;
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
  esac
  a=$((a+1));
done
}

second_part_function () {
printf "${BLUE}Configuring filesystems...${NC}\n";
mkdir /etc/zfs/zfs-list.cache;
touch /etc/zfs/zfs-list.cache/bpool;
touch /etc/zfs/zfs-list.cache/rpool;
ln -s /usr/lib/zfs/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d;
zed -F &
sleep 5;
printf "${GREEN}Please, check information about you filesystems:${NC}\n"
cache_pool_function "bpool" "on"; 
cache_pool_function "rpool" "noauto"; 
pkill zed;
sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/*;

printf "${BLUE}Installing extra packages...${NC}\n";
zypper install -y "$EXTRA_PACK";

if [ "$INITIAL_SNAP" = 1 ]
then printf "${BLUE}Creating initial snapshots...${NC}\n";
     zfs snapshot -r bpool/BOOT/suse@install;
     zfs snapshot -r rpool/ROOT/suse@install;
else :;
fi
}

if [ "$1" -eq 2 ]
then second_part_function; exit 0;
else :;
fi	

printf "${BLUE}Successfully chroot.${NC}\n";
ln -s /proc/self/mounts /etc/mtab;
printf "${BLUE}Refreshing repositories...${NC}\n";
if zypper refresh;
then :;
else printf "${RED}ERROR: Cant refesh repositories.${NC}\n";
fi
locale -a | grep -iP '(?<![\w\x27])C(?![\w\x27])|en_US.utf8|POSIX';
printf "${GREEN}Do you see all:${CYAN}C${GREEN}, ${CYAN}C.utf8${GREEN}, ${CYAN}en_US.utf8${GREEN} and ${CYAN}POSIX${GREEN} lines? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	printf "${ORANGE}Seems, that you have a problem with locales.
	Please check manually.
	or just answer \"y\" in next time.
	To start chroot install part again use:
	${PURPLE}/root/install/opensuse_install_zfs_chroot.sh${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

printf "${BLUE}Reinstalling some packages for stability...${NC}\n"
zypper install -fy permissions iputils ca-certificates ca-certificates-mozilla pam shadow dbus-1 libutempter0 suse-module-tools util-linux;
zypper install -y kernel-default kernel-firmware;

printf "${BLUE}Adding and refresh filesystem repository...${NC}\n";
zypper install -y lsb-release;
if zypper addrepo "https://download.opensuse.org/repositories/filesystems/$(lsb-release -rs)/filesystems.repo";
then if zypper refresh;
     then zypper install -y zfs;
     else printf "${RED}ERROR: Refresh repositories.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Add repository.${NC}\n"; exit 1;
fi

## genhostid.sh script taken from https://github.com/openzfs/zfs/files/4537537/genhostid.sh.gz

printf "${BLUE}Generating hostid...${NC}\n";
zgenhostid "$(/root/install/genhostid.sh)";
printf "${GREEN}Are ${CYAN}$(/root/install/genhostid.sh)${GREEN} and ${CYAN}$(hostid)${GREEN} values identical? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	printf "${ORANGE}Seems, that you have a problem with hostid.
	It can affect to the zfs pools mounting during the boot.
	Please check/install hostid manually.
	If you sure, that you hostid set right, just answer \"y\" next time.
	To start chroot install part again use:
	${PURPLE}/root/install/opensuse_install_zfs_chroot.sh${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

if [ "$BOOT_TYPE" -eq 2 ]
then printf "${BLUE}Preparing boot partition...${NC}\n";
     zypper install -y dosfstools;
     mkdosfs -F 32 -s 1 -n EFI "${DISK_0}-part1";
     mkdir /boot/efi;
     if grep efi /etc/fstab;
     then :;
     else echo "/dev/disk/by-id/${DISK_0}-part1 /boot/efi vfat defaults 0 0" >> /etc/fstab;
     fi
     mount /boot/efi;
else :;
fi     

printf "${GREEN}Set a root password:${NC}\n";
passwd;
printf "${BLUE}Enabling bpool importing...${NC}\n";
cp /root/install/zfs-import-bpool.service /etc/systemd/system/;
chown root:root /etc/systemd/system/zfs-import-bpool.service;
chmod 644 /etc/systemd/system/zfs-import-bpool.service;
systemctl enable zfs-import-bpool.service;

if [ "$ZFS_TMP" -eq 0 ]
then printf "${BLUE}Enabling tmpfs for /tmp...${NC}\n";
     cp /usr/share/systemd/tmp.mount /etc/systemd/system/;
     systemctl enable tmp.mount;
else :;
fi

printf "${BLUE}Kernel installing...${NC}\n";
echo 'zfs' > /etc/modules-load.d/zfs.conf;
kernel_version=`{ls -l /boot/vmlinuz-* | egrep -o '[[:digit:]]\.[[:digit:]]\.[[:digit:]]{2}\-[[:digit:]]{2}\.[[:digit:]]{2}-default'`;
if kernel-install add "$(uname -r)" "/boot/vmlinuz-$(uname -r)";
then :;
else printf "${RED}ERROR: Kernel install error, check installed version.${NC}\n"; exit 1;
fi	
mkinitrd;

printf "${BLUE}Bootloader installing...${NC}\n";
if [ "$BOOT_TYPE" -eq 1 ]
then printf "${ORANGE}Please, install bootloader for legacy (BIOS) manually. Stopping.
     After install bootloader, run script again, by:
     ${PURPLE}/root/install/opensuse_install_zfs_chroot.sh 2${NC}\n";
elif [ "$BOOT_TYPE" -eq 2 ]     
then if [ "$BOOT_LOADER" -eq 1 ]
     then printf "${ORANGE}Please, install grub bootloader for UEFI manually. Stopping. 
     After install bootloader, run script again by:
     ${PURPLE}/root/install/opensuse_install_zfs_chroot.sh 2${NC}\n";
     elif [ "$BOOT_LOADER" -eq 2 ]
     then systemd-machine-id-setup;
	  bootctl install;
	  cp /root/install/loader.conf /boot/efi/loader/;
	  chown root:root /boot/efi/loader/loader.conf;
	  chmod 755 /boot/efi/loader/loader.conf;
	  cp /root/install/openSUSE_Leap.conf /boot/efi/loader/entries/;
	  chown root:root /boot/efi/loader/entries/openSUSE_Leap.conf;
	  chmod 755 /boot/efi/loader/entries/openSUSE_Leap.conf;
	  mkdir /boot/efi/EFI/openSUSE;
	  cp -t /boot/efi/EFI/openSUSE /boot/vmlinuz /root/initrd;
	  bootctl update;
	  second_part_function; exit 0;
     else printf "${RED}ERROR: Check BOOT_LOADER variable.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Check BOOT_TYPE variable.${NC}\n"; exit 1;
fi
