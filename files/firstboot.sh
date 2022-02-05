#!/bin/sh
## by LordNicky
## v.1.0

. /root/lroz/lroz.conf

printf "${BLUE}Applying locale...${NC}\n"; 
localectl set-locale "$LOCALE";
printf "${GREEN}Do you want to add user account? (y/n)${NC}\n";
while true
do
  read -r user_reply;
  case "$user_reply" in 
	y|Y) printf "${BLUE}Ok, enter new user name:${NC}\n";
	;; 
	n|N) printf "${BLUE}Ok.${NC}\n"; 
	break;; 
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
  esac
  read -r user_name;
  zfs create "rpool/home/$user_name";
  useradd "$user_name";
  passwd "$user_name";
  cp -a /etc/skel/. "/home/$user_name";
  chown -R "$user_name":"$user_name" "/home/$user_name";
  usermod -a -G audio,cdrom,dip,floppy,netdev,plugdev,sudo,video "$user_name";
  printf "${GREEN}Do you want to add another user account? (y/n)${NC}\n";
done

printf "${BLUE}Generating kernel update script...${NC}\n";
kus="/root/kernel_update.sh";
echo '#!/bin/bash
kernel-install add $(uname -r) /boot/vmlinuz-$(uname -r);
mkinitrd;' > $kus;
if [ "$BOOT_TYPE" -eq 1 ]
then echo 'update-bootloader;
grub2-mkconfig -o /boot/grub2/grub.cfg;' >> $kus;
     a=0;
     while [ "$a" -lt "$DISK_NUM" ]
     do
	eval ofdisk='$DISK_'$a;
	echo "grub2-install ${ofdisk};" >> $kus;
	a=$((a+1));
     done
elif [ "$BOOT_TYPE" -eq 2 ]
then if [ "$BOOT_LOADER" -eq 1 ]
     then echo 'update-bootloader;
grub2-mkconfig -o /boot/grub2/grub.cfg;
grub2-install --target=$(uname -m)-efi --efi-directory=/boot/efi --bootloader-id=opensuse --recheck --no-floppy;' >> $kus
     elif [ "$BOOT_LOADER" -eq 2 ]
     then echo 'cp -t /boot/efi/EFI/openSUSE /boot/vmlinuz /root/initrd;
bootctl update;
mv /boot/efi/loader/entries/${cat /etc/machine-id}* /root/bootbak/;' >> $kus;
     fi
     echo 'umount /boot/efi;' >> $kus;
     b=1;
     while [ "$b" -lt "$DISK_NUM" ]
     do	
       eval ofdisk='$DISK_'$b;
       echo "dd if=${DISK_0}-part1 of=${ofdisk}-part1;" >> $kus;
       b=$((b+1));
     done
     echo "mount /boot/efi;" >> $kus;
fi     
chmod +x "$kus";

printf "${GREEN}Do you want to create zfs swap device? (y/n)${NC}\n";
read -r user_reply;
case "$user_reply" in
	y|Y) printf "${GREEN}Please, enter the size of swap? (4G, for example)${NC}\n";
	read -r swap_size; 
	zfs create -V "$swap_size" -b "$(getconf PAGESIZE)" -o compression=zle -o logbias=throughput -o sync=always -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false "${ZPOOL_NAME}/swap";
	mkswap -f "/dev/zvol/${ZPOOL_NAME}/swap";
	echo "/dev/zvol/${ZPOOL_NAME}/swap none swap discard 0 0" >> /etc/fstab;
	echo 'RESUME=none' > /etc/initramfs-tools/conf.d/resume;
	printf "${ORANGE}Please, if you saw warning about uncorrect volblocksize,
	recreate swap device after finishing this script by:
	${PURPLE}swapoff -av	
	zfs destroy rpool/swap
	zfs create -V $swap_size -o compression=zle -o logbias=throughput -o sync=always -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false rpool/swap
	mkswap -f /dev/zvol/rpool/swap
	swapon -av${NC}\n"
	;;
	n|N) printf "${BLUE}Ok, continue...${NC}\n";
	;;
	*) printf "${RED}No user reply, stopping.${NC}\n";
	exit 1;;
esac

if [ "$INSTALL_ZFSAUTOSNAP" -eq 1 ]
then printf "${BLUE}Installing zfs-auto-snapshot...${NC}\n";
     if zypper install -y cron;
     then wget -q -P /root/lroz https://github.com/zfsonlinux/zfs-auto-snapshot/archive/refs/heads/master.zip;
          unzip /root/lroz/master.zip;
	  cp /root/lroz/zfs-auto-snapshot-master/src/zfs-auto-snapshot.sh /usr/local/sbin/zfs-auto-snapshot;
	  cp /root/lroz/zfs-auto-snapshot-master/src/zfs-auto-snapshot.8 /usr/share/man/man8/;
	  cp /root/lroz/zfs-auto-snapshot.sh /etc/cron.d/zfs-auto-snapshot;
	  chmod +x /usr/local/sbin/zfs-auto-snapshot.sh;
          printf "${GREEN}Please, use ${PURPLE}man zfs-auto-snapshot${GREEN} to read usage instructions.\n";
          read -n 1 -s -r -p "Press any key to continue...";
          printf "${NC}\n";
     else printf "${RED}Failing of installing zfstools. Please, install them manually.${NC}";
     fi
fi

if [ "$INSTALL_ZFSTOOLS" -eq 1 ]
then printf "${BLUE}Installing zfstools...${NC}\n";
     if gem install zfstools;
     then cp /root/lroz/zfs-auto-snapshot.ruby /etc/cron.d/zfs-auto-snapshot;
     printf "${GREEN}Please, visit https://github.com/bdrewery/zfstools to read usage instructions.\n";
     read -n 1 -s -r -p "Press any key to continue...";
     printf "${NC}\n";
     else printf "${RED}Failing of installing zfstools. Please, install them manually.${NC}";
     fi
fi

if [ "$INSTALL_ZXFER" -eq 1 ]
then printf "${BLUE}Installing zxfer...${NC}\n";
     if zypper install -y man;
     then :;
     else printf "${ORANGE}You need to run:
     ${PURPLE}zypper install man
     ${ORANGE}if you want to read zxfer manual!${NC}";
     fi
     if zypper install -y wget;
     then wget -q -P /root/lroz https://github.com/allanjude/zxfer/archive/refs/heads/master.zip;
          unzip /root/lroz/master.zip -d /root/lroz;
          cp /root/lroz/zxfer-master/zxfer /usr/local/sbin/;
          cp /root/lroz/zxfer-master/zxfer.8 /usr/share/man/man8/;
          printf "${GREEN}Please, use ${PURPLE}man zxfer${GREEN} to read usage instructions.\n";
          read -n 1 -s -r -p "Press any key to continue...";
          printf "${NC}\n";
     else printf "${RED}Failing of installing zxfer. Please, install them manually.${NC}";
     fi
fi
