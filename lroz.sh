#!/bin/sh
## by LordNicky
## v.1.0

. ./lroz.conf

prep_func (){
printf "${ORANGE}01. PREPARING THE ENVIRONMENT. ${NC}\n";
printf "${BLUE}Initial cleaning...${NC}\n";
rm -f /etc/zypp/repos.d/filesystems.repo;

printf "${BLUE}Adding and refreshing repository...${NC}\n";
if zypper addrepo "$REPO2/repositories/filesystems/${repo_rel}/filesystems.repo";
then if zypper --gpg-auto-import-keys refresh;
     then :;
     else printf "${RED}ERROR: Refresh repositories.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Add repository.${NC}\n"; exit 1;
fi

## Disable gnome automounting
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
if [ "$SILENT" -eq 1 ]
then :;
else printf "${GREEN}You need to clean disk manually, if it used in a MD array.
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
fi     
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
       if [ -z "${ROOT_SIZE+x}" ];
       then eval sgdisk -n3:0:0 -t3:BF00 '$DISK'_$b;
       else eval sgdisk -n3:0:+"$ROOT_SIZE" -t3:BF00 '$DISK'_$b;
       fi
  elif [ -z "${ROOT_SIZE+x}" ];
  then eval sgdisk -n2:0:0 -t2:BF00 '$DISK'_$b;
  else eval sgdisk -n2:0:+"$ROOT_SIZE" -t2:BF00 '$DISK'_$b;
  fi
  b=$((b+1));
done

if [ "$SILENT" -eq 1 ]
then c=0;
     while [ "$c" -lt "$DISK_NUM" ]
     do
       if eval sgdisk --print '$DISK_'$c | grep "BF00";
       then :;
       else printf "${RED}Seems, that you have problem with partitions
	       at the DISK number $c.
	       Please, check them manually.${NC}\n"; exit 1;
       fi
       c=$((c+1));
     done
     sleep 5;
else printf "${GREEN}Please, check partitioning validity:${NC}\n";
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
fi     

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
     zpool create $RPOOL_OPT -R /mnt "$RPOOL_NAME" $ZPOOL_TYPE $rpool_parts;
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
zpool create $zpool_opts -R /mnt "$ZPOOL_NAME" $ZPOOL_TYPE $zpool_parts;

if [ "$SILENT" -eq 1 ]
then if zpool status | grep "$ZPOOL_NAME";
     then :;
     else printf "${RED}Seems, that you have problem with zfs pool creating. 
	     Please, check them manually.${NC}\n"; exit 1;
     fi
else printf "${GREEN}Please, check pools validity:${NC}\n";
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
fi     
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
#chmod a-w /mnt/etc/zfs/zpool.cache;
#chattr +i /mnt/etc/zfs/zpool.cache;

if [ "$SILENT" -eq 1 ]
then if zfs list | grep "$ZPOOL_NAME/ROOT";
     then :;
     else printf "${RED}Seems, that you have problem with zfs filesystems creating. 
	     Please, check them manually.${NC}\n"; exit 1;
     fi
else printf "${GREEN}Please, check created filesystems:${NC}\n";
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
fi     
}

sys_install_func () {
printf "${ORANGE}04. SYSTEM INSTALLATION.${NC}\n";
printf "${BLUE}Adding repos...${NC}\n";
if [ "$repo_rel" = "openSUSE_Tumbleweed" ]
then repo_rel_long="tumbleweed";
     if zypper --root /mnt addrepo "$REPO/update/${repo_rel_long}/" update;
     then :;
     else printf "${RED}ERROR: Can't add repository update to the new system.${NC}\n"; exit 1;
     fi
else repo_rel_long="leap/$repo_rel";
     if zypper --root /mnt addrepo "$REPO/update/${repo_rel_long}/oss" update-os;
     then :;
     else printf "${RED}ERROR: Can't add repository update-os to the new system.${NC}\n"; exit 1;
     fi
     if zypper --root /mnt addrepo "$REPO/update/${repo_rel_long}/non-oss" update-nonos;
     then :;
     else printf "${RED}ERROR: Can't add repository update-nonos to the new system.${NC}\n"; exit 1;
     fi
     repo_rel_long="distribution/$repo_rel_long";
fi
if zypper --root /mnt addrepo "$REPO/$repo_rel_long/repo/non-oss" non-os;
then :;
else printf "${RED}ERROR: Can't add repository non-os to the new system.${NC}\n"; exit 1;
fi
if zypper --root /mnt addrepo "$REPO/$repo_rel_long/repo/oss" os;
then :;
else printf "${RED}ERROR: Can't add repository os to the new system.${NC}\n"; exit 1;
fi
zypper --root /mnt --gpg-auto-import-keys refresh;
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
if [ -z "${INSTALL_YAST+x}" ];
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
mount --make-private --rbind /dev  /mnt/dev;
mount --make-private --rbind /proc /mnt/proc;
mount --make-private --rbind /sys  /mnt/sys;
mount -t tmpfs tmpfs /mnt/run;
mkdir /mnt/run/lock;
printf "${BLUE}Starting chroot configuration...${NC}\n";
chroot /mnt ln -s /proc/self/mounts /etc/mtab;

printf "${BLUE}Refreshing repositories under chroot...${NC}\n";
if zypper --root /mnt refresh;
then :;
else printf "${RED}ERROR: Cant refesh repositories.${NC}\n";
fi

printf "${BLUE}Cheking availability locales: ${CYAN}C${BLUE}, ${CYAN}C.utf8${BLUE}, ${CYAN}en_US.utf8${BLUE} and ${CYAN}POSIX${BLUE}... ${NC}\n";
if [ "$(chroot /mnt locale -a | grep -P '^C$')" = "C" ]
then if [ "$(chroot /mnt locale -a | grep -P '^C.utf8$')" = "C.utf8" ]
     then if [ "$(chroot /mnt locale -a | grep -P '^en_US.utf8$')" = "en_US.utf8" ]
          then if [ "$(chroot /mnt locale -a | grep -P '^POSIX$')" = "POSIX" ]
	       then :;
	       else printf "${ORANGE}Seems, that you have a problem with a ${CYAN}POSIX${ORANGE} locale. Please check them manually.
		       To start this install part again use: ${PURPLE}lroz.sh 5${NC}\n";
	       fi
	  else printf "${ORANGE}Seems, that you have a problem with a ${CYAN}en_US.utf8${ORANGE} locale. Please check them manually.
		  To start this install part again use: ${PURPLE}lroz.sh 5${NC}\n";
          fi
     else printf "${ORANGE}Seems, that you have a problem with a ${CYAN}C.utf8${ORANGE} locale. Please check them manually.
	     To start this install part again use: ${PURPLE}lroz.sh 5${NC}\n";
     fi
else printf "${ORANGE}Seems, that you have a problem with a ${CYAN}C${ORANGE} locale. Please check them manually.
	To start this install part again use: ${PURPLE}lroz.sh 5${NC}\n";
fi
	       
printf "${BLUE}Reinstalling some packages for stability...${NC}\n"
zypper --root /mnt install -fy permissions iputils ca-certificates ca-certificates-mozilla pam shadow dbus-1 libutempter0 suse-module-tools util-linux;
zypper --root /mnt install -y kernel-default kernel-firmware;

printf "${BLUE}Adding and refresh filesystem repository...${NC}\n";
if [ -e /mnt/etc/zypp/repos.d/filesystems.repo ] 
then :;
elif zypper --root /mnt addrepo "$REPO2/repositories/filesystems/${repo_rel}/filesystems.repo";
then if zypper --root /mnt --gpg-auto-import-keys refresh;
     then zypper --root /mnt up -y;
     zypper --root /mnt install -y zfs zfs-kmp-default;
     else printf "${RED}ERROR: Refresh repositories.${NC}\n"; exit 1;
     fi
else printf "${RED}ERROR: Add filesystems repository.${NC}\n"; exit 1;
fi

printf "${BLUE}Generating hostid...${NC}\n";
zgenhostid -f "$(./files/genhostid.sh)";
cp /etc/hostid /mnt/etc/;
if [ "$(./files/genhostid.sh)" = "$(chroot /mnt hostid)" ]
then :;
else printf "${ORANGE}Seems, that you have a problem with hostid.
	It can affect to the zfs pools mounting during the boot.
	Please install the same hostid in liveos and chroot manually.
	To start chroot install part again use:
	${PURPLE}lroz.sh 5${NC}\n"; exit 1; 
fi

if [ "$BOOT_TYPE" -eq 2 ]
then printf "${BLUE}Preparing boot partition...${NC}\n";
     if [ "$BOOT_LOADER" -eq 1 ]
     then zypper --root /mnt install -y "grub2-$(uname -m)-efi";
          echo 'export ZPOOL_VDEV_NAME_PATH=YES' >> /mnt/etc/profile;
          export ZPOOL_VDEV_NAME_PATH=YES;
     else :;
     fi
     zypper install -y dosfstools;
     mkdosfs -F 32 -s 1 -n EFI "${DISK_0}-part1";
     mkdir /mnt/boot/efi;
     if grep efi /mnt/etc/fstab;
     then :;
     else echo "${DISK_0}-part1 /boot/efi vfat defaults 0 0" >> /mnt/etc/fstab;
     fi
     chroot /mnt mount /boot/efi;
elif [ "$BOOT_TYPE" -eq 1 ]
then zypper --root /mnt install -y grub2-i386-pc;
     echo 'export ZPOOL_VDEV_NAME_PATH=YES' >> /mnt/etc/profile;
     export ZPOOL_VDEV_NAME_PATH=YES;
else :;
fi


if [ "$SILENT" -eq 1 ]
then echo "root:$ROOT_PASSWD" | chpasswd --root /mnt;
else printf "${GREEN}Set a root password:${NC}\n";
     passwd --root /mnt;
fi     

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

if [ "$GRUB_OPT" -eq  1 ]
then sed -i "s/^#GRUB_TERMINAL/GRUB_TERMINAL/" /mnt/etc/default/grub;
else :;
fi

if [ -z "${GRUB_PRM+x}" ]
then sed -i "s/^GRUB_CMDLINE_LINUX\=\"\"/GRUB_CMDLINE_LINUX\=\"${GRUB_PRM}\"/" /mnt/etc/default/grub;
else :;
fi
}

kern_install_func () {
printf "${ORANGE}06. KERNEL INSTALLATION.${NC}\n";
echo 'zfs' > /mnt/etc/modules-load.d/zfs.conf;
kernel_version=$(find /mnt/boot/vmlinuz-* | grep -Eo '[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*\-.*-default');
if chroot /mnt kernel-install add "$kernel_version" "/boot/vmlinuz-${kernel_version}";
then :;
else printf "${RED}ERROR: Kernel install error, check installed version.${NC}\n"; exit 1;
fi	
chroot /mnt mkinitrd;
}

bl_install_func () {
printf "${ORANGE}07. BOOTLOADER INSTALLATION.${NC}\n";
if [ "$BOOT_TYPE" -eq 1 ]
then chroot /mnt update-bootloader;
     chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg;
     g=0;
     while [ "$g" -lt "$DISK_NUM" ]
     do	
       eval chroot /mnt grub2-install '$DISK_'$g;
       g=$((g+1));
     done
elif [ "$BOOT_TYPE" -eq 2 ]     
then if [ "$BOOT_LOADER" -eq 1 ]
     then chroot /mnt update-bootloader;
          chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg;
          chroot /mnt grub2-install --target="$(uname -m)-efi" --efi-directory=/boot/efi --bootloader-id=opensuse --recheck --no-floppy;
     elif [ "$BOOT_LOADER" -eq 2 ]
     then chroot /mnt update-bootloader;
          chroot /mnt systemd-machine-id-setup;
	  chroot /mnt bootctl install;
	  sed -i "s/openSUSE.conf/openSUSE_${name_rel}.conf/" ./files/loader.conf
	  cp ./files/loader.conf /mnt/boot/efi/loader/;
	  chown root:root /mnt/boot/efi/loader/loader.conf;
	  chmod 755 /mnt/boot/efi/loader/loader.conf;
	  sed -i "s/openSUSE$/openSUSE ${name_rel}/" ./files/openSUSE.conf
          sed -i "s/zfs:.*\/suse/zfs\:${zp_name}\/ROOT\/suse/" ./files/openSUSE.conf 
	  cp ./files/openSUSE.conf "/mnt/boot/efi/loader/entries/openSUSE_${name_rel}.conf";
	  chown root:root "/mnt/boot/efi/loader/entries/openSUSE_${name_rel}.conf";
	  chmod 755 "/mnt/boot/efi/loader/entries/openSUSE_${name_rel}.conf";
	  mkdir /mnt/boot/efi/EFI/openSUSE;
	  cp -t /mnt/boot/efi/EFI/openSUSE /mnt/boot/vmlinuz /mnt/boot/initrd;
	  chroot /mnt bootctl update;
     else printf "${RED}ERROR: Check BOOT_LOADER variable.${NC}\n"; exit 1;
     fi
     if [ "$DISK_NUM" -gt 1 ]
     then chroot /mnt umount /boot/efi;
     h=1;
     while [ "$h" -lt "$DISK_NUM" ]
     do	
       eval ofdisk='$DISK_'$h;
       dd if="${DISK_0}-part1" of="${ofdisk}-part1";
       h=$((h+1));
     done
     chroot /mnt mount /boot/efi;
     else :;
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
if [ "$SILENT" -eq 1 ]
then :;
else printf "${GREEN}Please, check information about you filesystems:${NC}\n"
fi
if [ "$BOOT_PART" -eq 1 ]
then cache_pool_func "$zp_name" "on"; 
     cache_pool_func "$ZPOOL_NAME" "noauto";
else cache_pool_func "$zp_name" "noauto"; 
fi 
chroot /mnt pkill zed > /dev/null;
sed -Ei "s|/mnt/?|/|" /mnt/etc/zfs/zfs-list.cache/*;
}

cache_pool_func () {
f=0;
while [ "$f" -lt 4 ]
do	 
  if [ "$SILENT" -eq 1 ]
  then if grep "$ZPOOL_NAME" "/mnt/etc/zfs/zfs-list.cache/$1";
       then break;
       elif [ $f -eq 3 ]
       then printf "${ORANGE}You need manually check cache creating.
       After resolving cache problem, run script again by:
       ${PURPLE}lroz.sh 8${NC}\n";
       chroot /mnt pkill zed; exit 1;
       else zfs set "canmount=$2" "$1/BOOT/suse"; sleep 10;
       fi
  else cat "/mnt/etc/zfs/zfs-list.cache/$1";
       printf "${GREEN}Do you see all $1 filesystems? (y/n)${NC}\n";
       read -r user_reply;
       case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, continue...${NC}\n";
	break;; 
	n|N) if [ $f -eq 3 ]
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
  fi
  f=$((f+1));
done
}

add_config_func () {
printf "${ORANGE}09. ADDITIONAL CONFIGURATION.${NC}\n";
printf "${BLUE}Installing extra packages...${NC}\n";
zypper --root /mnt install -y $EXTRA_PACK;

if [ "$INITIAL_SNAP" -eq 1 ]
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
sleep 10;
rm /etc/zfs/zpool.cache;

printf "${ORANGE}After boot to the new installed System,
to do some after-installation steps, run:
/root/lroz/firstboot.sh${NC}\n";

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
then name_rel="Leap";
     repo_rel=$(lsb_release -rs);
elif [ "$(lsb_release -d | grep -o 'Tumbleweed')" = "Tumbleweed" ]
then name_rel="Tumbleweed"
     repo_rel="openSUSE_Tumbleweed";
else printf "${RED}openSUSE release definition error ! Exiting.${NC}\n"; exit 1;
fi

if [ "$BOOT_PART" -eq 1 ]
then zp_name="$RPOOL_NAME";
else zp_name="$ZPOOL_NAME";
fi

func=${1:-0};

if [ "$func" -eq 1 ]
then prep_func; exit 0;
else :;
fi	
if [ "$func" -eq 2 ]
then disk_format_func; exit 0;
else :;
fi	
if [ "$func" -eq 3 ]
then create_fs_func; exit 0;
else :;
fi	
if [ "$func" -eq 4 ]
then sys_install_func; exit 0;
else :;
fi	
if [ "$func" -eq 5 ]
then sys_config_func; exit 0;
else :;
fi	
if [ "$func" -eq 6 ]
then kern_install_func; exit 0;
else :;
fi	
if [ "$func" -eq 7 ]
then bl_install_func; exit 0;
else :;
fi	
if [ "$func" -eq 8 ]
then fs_config_func; exit 0;
else :;
fi	
if [ "$func" -eq 9 ]
then add_config_func; exit 0;
else :;
fi	
if [ "$func" -eq 10 ]
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
ZPOOLs on the DISKs used to install the system must be MANUALLY cleaned!
${GREEN}If you want continue by ssh,
you need install openssh-server, enable pass and start service:
${PURPLE}sudo zypper in -y openssh-server
sudo systemctl restart sshd.service
sudo passwd
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
