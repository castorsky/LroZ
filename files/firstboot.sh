#!/bin/sh

. /root/install/opensuse_install_zfs.conf

printf "${BLUE}Applying locale...${NC}\n"; 
localectl set-locale "$LOCALE";
printf "${GREEN}Do you want to add user account?${NC}\n";
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
  printf "${GREEN}Do you want to add another user account?${NC}\n";
done

printf "${BLUE}Generating kernel update script...${NC}\n";
kus="/root/kernel_update.sh";
echo '#!/bin/bash
kernel-install add $(uname -r) /boot/vmlinuz-$(uname -r);
mkinitrd;
update-bootloader;' > $kus;
if [ "$BOOT_LOADER" -eq 2 ]
then echo 'cp -t /boot/efi/EFI/openSUSE /boot/vmlinuz /root/initrd;
bootctl update;
mv /boot/efi/loader/entries/${cat /etc/machine-id}* /root/bootbak/;' >> $kus;
else :;
fi
if [ "$BOOT_TYPE" -eq 2 ]
then echo 'umount /boot/efi;' >> $kus;
     b=1;
     while [ "$b" -lt "$DISK_NUM" ]
     do	
       eval ofdisk='$DISK_'$b;
       echo "dd if=${DISK_0}-part1 of=${ofdisk}-part1;" >> $kus;
     done
     echo "mount /boot/efi;" >> $kus;
else :;
fi     

printf "${GREEN}Do you want to create zfs swap device?${NC}\n";
read -r user_reply;
case "$user_reply" in
	y|Y) printf "${BLUE}Please, enter the size of swap? (4G, for example)${NC}\n";
	read -r swap_size; 
	zfs create -V "$swap_size" -b "$(getconf PAGESIZE)" -o compression=zle -o logbias=throughput -o sync=always -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false rpool/swap;
	mkswap -f /dev/zvol/rpool/swap;
	echo '/dev/zvol/rpool/swap none swap discard 0 0' >> /etc/fstab;
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

