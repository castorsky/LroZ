#!/bin/sh
## by LordNicky

. ./lroz.conf

prep_func (){
printf "${ORANGE}01. PREPARING THE ENVIRONMENT. ${NC}\n";
printf "${BLUE}Initial cleaning...${NC}\n";
rm -f /etc/zypp/repos.d/filesystems.repo;

printf "${BLUE}Adding and refreshing repository...${NC}\n";
if zypper addrepo "https://download.opensuse.org/repositories/filesystems/${fs_repo}/filesystems.repo";
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
}

disk_format_func () {
printf "${ORANGE}02. DISK FORMATTING.${NC}\n";
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
  if [ "$BOOT_PART" -eq 1 ]
  then eval sgdisk -n2:0:+1G -t2:BF01 '$DISK'_$b;
       if [ -z "$ROOT_SIZE" ];
       then eval sgdisk -n3:0:0 -t3:BF00 '$DISK'_$b;
       else eval sgdisk -n3:0:+"$ROOT_SIZE" -t3:BF00 '$DISK'_$b;
       fi
  elif [ -z "$ROOT_SIZE" ];
  then eval sgdisk -n2:0:0 -t2:BF00 '$DISK'_$b;
  else eval sgdisk -n2:0:+"$ROOT_SIZE" -t2:BF00 '$DISK'_$b;
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

if [ "$BOOT_PART" -eq 1 ]
then zpool_opts="$ZPOOL_OPT -O mountpoint=/boot";
     printf "${BLUE}Creating $RPOOL_NAME pool...${NC}\n"
     e=0;
     rpool_parts="";
     while [ "$e" -lt "$DISK_NUM" ]
     do	
       eval rp_part='$DISK_'$e-part3;
       rpool_parts="$rpool_parts $rp_part";
       e=$((e+1));
     done
     zpool create $RPOOL_OPT -R /mnt "$RPOOL_NAME" "$ZPOOL_TYPE" $rpool_parts;
else zpool_opts="$ZPOOL_OPT -O mountpoint=/";
fi

printf "${BLUE}Creating $ZPOOL_NAME pool.${NC}\n";
d=0;
zpool_parts="";
while [ "$d" -lt "$DISK_NUM" ]
do	
  eval bp_part='$DISK_'$d-part2;
  zpool_parts="$zpool_parts $bp_part";
  d=$((d+1));
done
zpool create $zpool_opts -R /mnt "$ZPOOL_NAME" "$ZPOOL_TYPE" $zpool_parts;

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
}

create_fs_func () {
printf "${ORANGE}03. CREATING FILESYSTEMS.${NC}\n";
zfs create -o canmount=off -o mountpoint=none "$zp_name/ROOT";
zfs create -o canmount=noauto -o mountpoint=/ "$zp_name/ROOT/suse";
zfs mount "$zp_name/ROOT/suse";
if [ "$BOOT_PART" -eq 1 ]
then zfs create -o canmount=off -o mountpoint=none "$ZPOOL_NAME/BOOT";
     zfs create -o mountpoint=/boot "$ZPOOL_NAME/BOOT/suse";
else zfs create "$zp_name/boot";
fi
zfs create "$zp_name/home";
zfs create -o mountpoint=/root "$zp_name/home/root";
chmod 700 /mnt/root;
zfs create -o canmount=off "$zp_name/var";
zfs create -o canmount=off "$zp_name/var/lib";
zfs create "$zp_name/var/log";
zfs create "$zp_name/var/spool";
if [ "$ZFS_CACHE" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  "$zp_name/var/cache";
else :;
fi	
if [ "$ZFS_VARTMP" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  "$zp_name/var/tmp";
     chmod 1777 /mnt/var/tmp;
else :;
fi
if [ "$ZFS_OPT" -eq 1 ]
then zfs create "$zp_name/opt";
else :;
fi
if [ "$ZFS_SRV" -eq 1 ]
then zfs create "$zp_name/srv";
else :;
fi
if [ "$ZFS_LOCAL" -eq 1 ]
then zfs create -o canmount=off "$zp_name/usr";
     zfs create "$zp_name/usr/local";
else :;
fi
if [ "$ZFS_GAMES" -eq 1 ]
then zfs create "$zp_name/var/games";
else :;
fi
if [ "$ZFS_MAIL" -eq 1 ]
then zfs create "$zp_name/var/mail";
else :;
fi
if [ "$ZFS_SNAP" -eq 1 ]
then zfs create "$zp_name/var/snap";
else :;
fi
if [ "$ZFS_WWW" -eq 1 ]
then zfs create "$zp_name/var/www";
else :;
fi
if [ "$ZFS_FLAT" -eq 1 ]
then zfs create "$zp_name/var/lib/flatpak";
else :;
fi
if [ "$ZFS_GNOME" -eq 1 ]
then zfs create "$zp_name/var/lib/AccountsService";
else :;
fi
if [ "$ZFS_DOCKER" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  "$zp_name/var/lib/docker";
else :;
fi
if [ "$ZFS_NFS" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  "$zp_name/var/lib/nfs";
else :;
fi
mkdir /mnt/run;
mount -t tmpfs tmpfs /mnt/run;
mkdir /mnt/run/lock;
if [ "$ZFS_TMP" -eq 1 ]
then zfs create -o com.sun:auto-snapshot=false  "$zp_name/tmp";
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
}

sys_install_func () {
printf "${ORANGE}04. SYSTEM INSTALLATION.${NC}\n";
printf "${BLUE}Adding repos...${NC}\n";
if [ "$fs_repo" = "openSUSE_Tumbleweed" ]
then fs_repo_long="tumbleweed";
     if zypper --root /mnt ar "http://download.opensuse.org/update/${fs_repo_long}/" update;
     then :;
     else printf "${RED}ERROR: Can't add repository update to the new system.${NC}\n"; exit 1;
     fi
else fs_repo_long="distribution/leap/$fs_repo";
     if zypper --root /mnt ar "http://download.opensuse.org/${fs_repo_long}/oss" update-os;
     then :;
     else printf "${RED}ERROR: Can't add repository update-os to the new system.${NC}\n"; exit 1;
     fi
     if zypper --root /mnt ar "http://download.opensuse.org/${fs_repo_long}/non-oss" update-nonos;
     then :;
     else printf "${RED}ERROR: Can't add repository update-nonos to the new system.${NC}\n"; exit 1;
     fi
fi
if zypper --root /mnt ar "http://download.opensuse.org/${fs_repo_long}/repo/non-oss" non-os;
then :;
else printf "${RED}ERROR: Can't add repository non-os to the new system.${NC}\n"; exit 1;
fi
if zypper --root /mnt ar "http://download.opensuse.org/${fs_repo_long}/repo/oss" os;
then :;
else printf "${RED}ERROR: Can't add repository os to the new system.${NC}\n"; exit 1;
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
     elif zypper --root /mnt install yast2;
     then :;
     else printf "${RED}ERROR: Can't install yast2.${NC}\n"; exit 1;
     fi
     if zypper --root /mnt install -y -t pattern "$INSTALL_YAST";
     then :;
     elif zypper --root /mnt install -t pattern "$INSTALL_YAST";
     then :;
     else printf "${RED}ERROR: Can't install $INSTALL_YAST .${NC}\n"; exit 1;
     fi
fi     
}

sys_config_func () {
printf "${ORANGE}05. SYSTEM CONFIGURATION.${NC}\n";
printf "$HOST_NAME" > /mnt/etc/hostname;
if grep "$HOST_NAME" /mnt/etc/hosts;
then printf "127.0.1.1	$HOST_FQDN $HOST_NAME" >> /mnt/etc/hosts;
else :;
fi
rm /mnt/etc/resolv.conf;
cp /etc/resolv.conf /mnt/etc/;
mount --make-private --rbind /dev  /mnt/dev;
mount --make-private --rbind /proc /mnt/proc;
mount --make-private --rbind /sys  /mnt/sys;
mount -t tmpfs tmpfs /mnt/run;
mkdir /mnt/run/lock;
printf "${BLUE}Starting chroot configuration...${NC}\n";
chroot /mnt ln -s /proc/self/mounts /etc/mtab;
printf "${BLUE}Refreshing repositories under chroot...${NC}\n";
if chroot /mnt zypper refresh;
then :;
else printf "${RED}ERROR: Cant refesh repositories.${NC}\n";
fi
printf "${BLUE}Cheking available locales...${NC}\n";
chroot /mnt locale -a | grep -iP '(?<![\w\x27])C(?![\w\x27])|en_US.utf8|POSIX';
printf "${GREEN}Do you see all: ${CYAN}C${GREEN}, ${CYAN}C.utf8${GREEN}, ${CYAN}en_US.utf8${GREEN} and ${CYAN}POSIX${GREEN} lines? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	printf "${ORANGE}Seems, that you have a problem with locales.
	Please check manually.
	or just answer \"y\" in next time.
	To start this install part again use:
	${PURPLE}lroz.sh 5${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

printf "${BLUE}Reinstalling some packages for stability...${NC}\n"
chroot /mnt zypper install -fy permissions iputils ca-certificates ca-certificates-mozilla pam shadow dbus-1 libutempter0 suse-module-tools util-linux;
chroot /mnt zypper install -y kernel-default kernel-firmware;

printf "${BLUE}Adding and refresh filesystem repository...${NC}\n";
if [ -e /mnt/etc/zypp/repos.d/filesystems.repo ] 
then :;
elif chroot /mnt zypper addrepo "https://download.opensuse.org/repositories/filesystems/${fs_repo}/filesystems.repo";
then if chroot /mnt zypper refresh;
     then chroot /mnt zypper install -y zfs;
     else printf "${RED}ERROR: Refresh repositories.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Add filesystems repository.${NC}\n"; exit 1;
fi

## genhostid.sh script taken from https://github.com/openzfs/zfs/files/4537537/genhostid.sh.gz

printf "${BLUE}Generating hostid...${NC}\n";
zgenhostid "$(./files/genhostid.sh)";
cp /etc/hostid /mnt/etc/;
printf "${GREEN}Are ${CYAN}$(./files/genhostid.sh)${GREEN} and ${CYAN}$(chroot /mnt hostid)${GREEN} values identical? (y/n)${NC}\n";
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
	${PURPLE}lroz.sh 5${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

if [ "$BOOT_TYPE" -eq 2 ]
then printf "${BLUE}Preparing boot partition...${NC}\n";
## MAY BE dosfstools NEEDS IN OS!
     zypper install -y dosfstools;
     mkdosfs -F 32 -s 1 -n EFI "${DISK_0}-part1";
     mkdir /mnt/boot/efi;
     if grep efi /mnt/etc/fstab;
     then :;
     else echo "/dev/disk/by-id/${DISK_0}-part1 /boot/efi vfat defaults 0 0" >> /mnt/etc/fstab;
     fi
     chroot /mnt mount /boot/efi;
else :;
fi

printf "${GREEN}Set a root password:${NC}\n";
chroot /mnt passwd;

if [ "$BOOT_PART" -eq 1 ]
then printf "${BLUE}Enabling bpool importing...${NC}\n";
     cp ./files/zfs-import-bpool.service /mnt/etc/systemd/system/;
     chown root:root /mnt/etc/systemd/system/zfs-import-bpool.service;
     chmod 644 /mnt/etc/systemd/system/zfs-import-bpool.service;
     chroot /mnt systemctl enable zfs-import-bpool.service;
else :;
fi     

if [ "$ZFS_TMP" -eq 0 ]
then printf "${BLUE}Enabling tmpfs for /tmp...${NC}\n";
     cp /mnt/usr/share/systemd/tmp.mount /mnt/etc/systemd/system/;
     chroot /mnt systemctl enable tmp.mount;
else :;
fi
}

kern_install_func () {
printf "${ORANGE}06. KERNEL INSTALLATION.${NC}\n";
echo 'zfs' > /mnt/etc/modules-load.d/zfs.conf;
kernel_version=$(find /mnt/boot/vmlinuz-* | grep -Eo '[[:digit:]]\.[[:digit:]]{1,2}\.[[:digit:]]{1,2}\-[[:digit:]]{1,2}*-default');
if chroot /mnt kernel-install add "$kernel_version" "/boot/vmlinuz-${kernel_version}";
then :;
else printf "${RED}ERROR: Kernel install error, check installed version.${NC}\n"; exit 1;
fi	
chroot /mnt mkinitrd;
}

bl_install_func () {
printf "${ORANGE}07. BOOTLOADER INSTALLATION.${NC}\n";
if [ "$BOOT_TYPE" -eq 1 ]
then chroot /mnt zypper install -y grub2;
     echo 'export ZPOOL_VDEV_NAME_PATH=YES' >> /mnt/etc/profile;
     export ZPOOL_VDEV_NAME_PATH=YES;
#     sed -i "s|rpool=.*|rpool=\`zdb -l \${GRUB_DEVICE} \| grep -E '[[:blank:]]name' \| cut -d\\\' -f 2\`|"  /mnt/etc/grub.d/10_linux;
     echo 'GRUB_ENABLE_BLSCFG=false' >> /mnt/etc/default/grub;
#     sed -i "s|^#GRUB_TERMINAL|GRUB_TERMINAL|" /mnt/etc/default/grub;
#     sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"root=ZFS=$zp_name/ROOT/suse\"|" /etc/default/grub;
     mkdir /mnt/root/lroz;
     cp ./files/initrd.sh /mnt/root/lroz/;
     chroot /mnt /root/lroz/initrd.sh;
     chroot /mnt update-bootloader;
     chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg;
     b=0;
     while [ "$b" -lt "$DISK_NUM" ]
     do	
       eval chroot /mnt grub2-install '$DISK_'$b;
       b=$((b+1));
     done
elif [ "$BOOT_TYPE" -eq 2 ]     
then if [ "$BOOT_LOADER" -eq 1 ]
     then printf "${ORANGE}Please, install grub bootloader for UEFI manually. Stopping. 
     After install bootloader, run script again by:
     ${PURPLE}lroz.sh 8${NC}\n";
     elif [ "$BOOT_LOADER" -eq 2 ]
     then chroot /mnt systemd-machine-id-setup;
	  chroot /mnt bootctl install;
	  cp ./files/loader.conf /mnt/boot/efi/loader/;
	  chown root:root /mnt/boot/efi/loader/loader.conf;
	  chmod 755 /mnt/boot/efi/loader/loader.conf;
	  cp ./files/openSUSE_Leap.conf /mnt/boot/efi/loader/entries/;
	  chown root:root /mnt/boot/efi/loader/entries/openSUSE_Leap.conf;
	  chmod 755 /mnt/boot/efi/loader/entries/openSUSE_Leap.conf;
	  mkdir /mnt/boot/efi/EFI/openSUSE;
	  cp -t /mnt/boot/efi/EFI/openSUSE /mnt/boot/vmlinuz /mnt/root/initrd;
	  chroot /mnt bootctl update;
     else printf "${RED}ERROR: Check BOOT_LOADER variable.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Check BOOT_TYPE variable.${NC}\n"; exit 1;
fi
}

fs_config_func () {
printf "${ORANGE}08. FILESYSTEM CONFIGURATION.${NC}\n";
mkdir /mnt/etc/zfs/zfs-list.cache;
touch "/mnt/etc/zfs/zfs-list.cache/$zp_name";
if [ "$BOOT_PART" -eq 1 ]
then touch "/etc/zfs/zfs-list.cache/$ZPOOL_NAME";
else :;
fi
chroot /mnt ln -s /usr/lib/zfs/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d;
chroot /mnt zed -F &
sleep 5;
printf "${GREEN}Please, check information about you filesystems:${NC}\n"
if [ "$BOOT_PART" -eq 1 ]
then cache_pool_func "$zp_name" "on"; 
     cache_pool_func "$ZPOOL_NAME" "noauto";
else cache_pool_func "$zp_name" "noauto"; 
fi 
chroot /mnt pkill zed;
sed -Ei "s|/mnt/?|/|" /mnt/etc/zfs/zfs-list.cache/*;
}

cache_pool_func () {
a=0;
while [ "$a" -lt 4 ]
do	 
  cat "/mnt/etc/zfs/zfs-list.cache/$1";
  if [ $a -lt 1 ] 
  then printf "${GREEN}Do you see all $1 filesystems?${NC}\n";
  else printf "${GREEN}And now?${NC}\n";
  fi
  read -r user_reply;
  case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	break;; 
	n|N) if [ $a -eq 3 ]
	     then printf "${ORANGE}You need manually check cache creating.
	     After resolving cache problem, run script again by:
             ${PURPLE}lroz.sh 8${NC}\n";
	     chroot /mnt pkill zed; exit 1;
	     else zfs set "canmount=$2" "$1/BOOT/suse"; sleep 10;
	     fi 
	     ;;
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
  esac
  a=$((a+1));
done
}

add_config_func () {
printf "${ORANGE}09. ADDITIONAL CONFIGURATION.${NC}\n";
printf "${BLUE}Installing extra packages...${NC}\n";
zypper install -y $EXTRA_PACK;

if [ "$INITIAL_SNAP" = 1 ]
then printf "${BLUE}Creating initial snapshots...${NC}\n";
     zfs snapshot -r "$zp_name@install";
     if [ "$BOOT_PART" -eq 1 ]
     then zfs snapshot -r "$ZPOOL_NAME@install";
     else :;
     fi
else :;
fi
}

finish_func () {
printf "${ORANGE}10. FINISHING.${NC}\n";
mkdir /mnt/root/lroz;
cp -t /mnt/root/lroz/ ./files/firstboot.sh ./lroz.conf;

printf "${BLUE}Unmounting and exporting zpools...${NC}\n";
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {};
zpool export -a;
rm /etc/hostid;

printf "${ORANGE}After boot to the new installed System,
to do some after-installation steps, run:
/root/install/lroz_firstboot.sh${NC}\n";

printf "${GREEN}Do you want to reboot, now? (y/n)
y - for reboot
n - for exit to shell${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, rebooting...
	Don't forget to detach installation disk!${NC}\n";
	sleep 5; reboot; sleep 5; exit 0;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac
}	

if whoami | grep -q "root";
then :;
else printf "${RED}You must run script as root! Exiting.${NC}\n"; exit 1;
fi

if [ "$(lsb_release -d | grep -o 'Leap')" = "Leap" ]
then fs_repo=$(lsb_release -rs);
elif [ "$(lsb_release -d | grep -o 'Tumbleweed')" = "Tumbleweed" ]
then fs_repo="openSUSE_Tumbleweed";
else printf "${RED}openSUSE release definition error ! Exiting.${NC}\n"; exit 1;
fi

if [ "$BOOT_PART" -eq 1 ]
then zp_name="$RPOOL_NAME";
else zp_name="$ZPOOL_NAME";
fi	

if [ "$1" -eq 1 ]
then prep_func; exit 0;
else :;
fi	
if [ "$1" -eq 2 ]
then disk_format_func; exit 0;
else :;
fi	
if [ "$1" -eq 3 ]
then create_fs_func; exit 0;
else :;
fi	
if [ "$1" -eq 4 ]
then sys_install_func; exit 0;
else :;
fi	
if [ "$1" -eq 5 ]
then sys_config_func; exit 0;
else :;
fi	
if [ "$1" -eq 6 ]
then kern_install_func; exit 0;
else :;
fi	
if [ "$1" -eq 7 ]
then bl_install_func; exit 0;
else :;
fi	
if [ "$1" -eq 8 ]
then fs_config_func; exit 0;
else :;
fi	
if [ "$1" -eq 9 ]
then add_config_func; exit 0;
else :;
fi	
if [ "$1" -eq 10 ]
then finish_func; exit 0;
else :;
fi	

printf "${GREEN}Hi! This script will help you to install OpenSUSE
with using zfs filesystem.
${ORANGE}You need a working network before we will start.
Also you need to start this script as root.
And finally you must to set a preferred values
for variables in lroz.conf!
Please check, that all .sh files
of installation scripts are executables. 
${GREEN}If you want continue by ssh,
you need install openssh-server, enable pass and start service:
${PURPLE}sudo zypper in -y openssh-server
sudo systemctl restart sshd.service
sudo passwd
${ORANGE}Please, accept new keys for repos during installation (a).
${GREEN}You can run lroz for any installations steps separately, if it neccessary:
lroz.sh [step_number] where step_number is a number of installation step:
1 - preparation
2 - disk formatting
3 - filesystems creating
4 - system installation
5 - system configuration
6 - kernel installation
7 - bootloader installation
8 - filesystem configuration
9 - additional configuration
10 - finish installation${NC}\n
${GREEN}Proceed installation from the begin? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok, stopping.${NC}\n"; 
	exit 0;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

prep_func;
disk_format_func;
create_fs_func;
sys_install_func;
sys_config_func;
kern_install_func;
bl_install_func;
fs_config_func;
add_config_func;
finish_func;
