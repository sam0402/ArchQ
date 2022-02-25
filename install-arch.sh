#!/bin/bash
# WARNING: this script will destroy data on the selected disk.
# This script can be run by executing the following:
#   curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/install-arch.sh | bash
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

MIRRORLIST_URL="https://archlinux.org/mirrorlist/?country=GB&protocol=https&use_mirror_status=on"

pacman -Sy --noconfirm pacman-contrib dialog

echo "Updating mirror list"
curl -s "$MIRRORLIST_URL" | \
    sed -e 's/^#Server/Server/' -e '/^#/d' | \
    rankmirrors -n 5 - > /etc/pacman.d/mirrorlist

### Get infomation from user ###
hostname=$(dialog --stdout --title "ArchQ" --inputbox "Enter hostname" 0 0) || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(dialog --stdout --title "ArchQ" --inputbox "Enter admin username" 0 0) || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(dialog --stdout --title "ArchQ" --inputbox "Enter admin password" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
password2=$(dialog --stdout --title "ArchQ" --inputbox "Enter admin password again" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --title "ArchQ" --menu "Select installtion disk" 0 0 0 ${devicelist}) || exit 1
clear

fmt=$(dialog  --stdout --title "ArchQ" --menu "Format ${device}" 7 0 0 F "Full disk" R "Retain database") || exit 1
clear

f2fs=$(dialog  --stdout --title "ArchQ" --menu "Format ${device} file system" 8 0 0 F "F2FS (SSD,Flash)" X "XFS (HDD)") || exit 1
clear

lang=$(dialog  --stdout --title "ArchQ" --menu "Select language" 7 0 0 E "en_US" J "ja_JP" T "zh_TW") || exit 1
clear

ip=$(dialog  --stdout --title "ArchQ" --menu "Select IP setting" 7 0 0 D "DHCP" S "Static IP") || exit 1
clear

if [ $ip = S ]; then
ethers=$(ip -o link show | awk '{print $2,$9}' | grep '^en' | sed 's/://')
ifport=$(dialog --stdout --title "ArchQ" --menu "Select net device" 7 0 0 ${ethers}) || exit 1
clear

ifmask=24; ifdns=8.8.8.8
ifconfig=$(dialog --stdout --title "ArchQ" --ok-label "Ok" --form "Enter $ifport IP setting" 10 35 0 \
            "Address" 1 1   ""          1 10 15 0 \
            "Netmask" 2 1   "$ifmask"   2 10 15 0 \
            "Gateway" 3 1   ""          3 10 15 0 \
            "DNS"     4 1   "$ifdns"    4 10 15 0) || exit 1
clear

ifaddr=$(echo $ifconfig | cut -d' ' -f1)
ifmast=$(echo $ifconfig | cut -d' ' -f2)
ifgw=$(echo $ifconfig | cut -d' ' -f3)
ifdns=$(echo $ifconfig | cut -d' ' -f4)
fi

player=N
server=$(dialog --stdout --title "ArchQ" --menu "Select music server" 7 0 0 L LMS M MPD R Roon N None) || exit 1
clear
case $server in
    L)
        player=$(dialog --stdout --title "ArchQ" --menu "Squeezelite Enable" 7 0 0 S Enable N Disable) || exit 1
        ;;
    N)
        player=$(dialog --stdout --title "ArchQ" \
                --checklist "Select music player" 7 0 0 \
                S Squeezelite on \
                A Airplay off \
                R Roonbridge off ) || exit 1
        ;;
esac
clear

### Set up logging ###
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

timedatectl set-ntp true

### Setup the disk and partitions ###
if [ $fmt = F ]; then
#swap_size=$(free --mebi | awk '/Mem:/ {print $2}')
  swap_size=256
  root_size=4096
  swap_end=$(( $swap_size + 257 + 1 ))MiB
  root_end=$(( $root_size + $swap_size + 257 + 1 ))MiB
  parted --script "${device}" -- mklabel gpt \
    mkpart ESP fat32 1Mib 257MiB \
    set 1 boot on \
    mkpart primary linux-swap 257MiB ${swap_end} \
    mkpart primary ext4 ${swap_end} ${root_end} \
    mkpart primary ext4 ${root_end} 100%
fi
# Simple globbing was not enough as on one device I needed to match /dev/mmcblk0p1 
# but not /dev/mmcblk0boot1 while being able to match /dev/sda1 on other devices.
part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"
part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"
part_root="$(ls ${device}* | grep -E "^${device}p?3$")"
part_data="$(ls ${device}* | grep -E "^${device}p?4$")"

wipefs "${part_boot}"
wipefs "${part_swap}"
wipefs "${part_root}"
wipefs "${part_data}"

mkfs.vfat -F32 "${part_boot}"
mkswap "${part_swap}"
if [ $f2fs = F ]; then
    mkfs.f2fs -fl root "${part_root}"
    [ $fmt = F ] && mkfs.f2fs -fl data "${part_data}"
else
    mkfs.xfs -fL root "${part_root}"
    [ $fmt = F ] && mkfs.xfs -fL data "${part_data}"
fi
swapon "${part_swap}"

mount "${part_root}" /mnt
mkdir /mnt/boot
mount "${part_boot}" /mnt/boot
case $server in
    L)
        [ ! -d /mnt/opt/logitechmediaserver ] && mkdir -p /mnt/opt/logitechmediaserver
        mount "${part_data}" /mnt/opt/logitechmediaserver
        ;;
    M)
        [ ! -d /mnt/var/lib/mpd ] && mkdir -p /mnt/var/lib/mpd
        mount "${part_data}" /mnt/var/lib/mpd
        ;;
    R)
        [ ! -d /mnt/var/roon ] && mkdir -p /mnt/var/roon
        mount "${part_data}" /mnt/var/roon
        ;;
esac

cpu=intel; cat /proc/cpuinfo | grep -q AMD && cpu=amd

pacstrap /mnt base linux linux-firmware ${cpu}-ucode grub efibootmgr gptfdisk f2fs-tools xfsprogs networkmanager openssh dhclient vim nano wget avahi sudo dialog cpupower
genfstab -Up /mnt | sed '/^$/d' >>/mnt/etc/fstab

echo "${hostname}" > /mnt/etc/hostname
echo "nameserver 8.8.8.8" >> /mnt/etc/resolv.conf
echo "nameserver 1.1.1.1" >> /mnt/etc/resolv.conf
arch-chroot /mnt useradd -mU "$user"
sed -i '82s/# %wheel/%wheel/' /mnt/etc/sudoers
arch-chroot /mnt usermod -aG wheel $user

### Set locale language
echo "en_US.UTF-8 UTF-8" >/mnt/etc/locale.gen
echo "ja_JP.UTF-8 UTF-8" >>/mnt/etc/locale.gen
echo "zh_TW.UTF-8 UTF-8" >>/mnt/etc/locale.gen
arch-chroot /mnt locale-gen
[ $lang = E ] && echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
[ $lang = J ] && echo "LANG=ja_JP.UTF-8" > /mnt/etc/locale.conf
[ $lang = T ] && echo "LANG=zh_TW.UTF-8" > /mnt/etc/locale.conf
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Taipei /etc/localtime
[ $lang = J ] && arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# echo "$user:$password" | chpasswd --root /mnt
arch-chroot /mnt sh -c "echo $user:$password | chpasswd"
# echo "root:$password" | chpasswd --root /mnt
arch-chroot /mnt sh -c "echo root:$password | chpasswd"
arch-chroot /mnt mkinitcpio -p linux
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=${hostname}
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo $device | grep -q nvme && sed -i 's/MODULES=()/MODULES=(nvme)/' /mnt/etc/mkinitcpio.conf
[ $f2fs = X ] && sed -i 's/MODULES=()/MODULES=(xfs)/' /mnt/etc/mkinitcpio.conf

arch-chroot /mnt ln -s /usr/bin/vim /usr/bin/vi

### Ethernet IP
echo ......................
if [ $ip = D ]; then
    echo Install DHCP Client...
    cat >/mnt/etc/NetworkManager/conf.d/dhcp-client.conf <<EOF
[main]
dhcp=dhclient
EOF
    cat >/mnt/etc/NetworkManager/conf.d/dns.conf <<EOF
[main]
dns=none
systemd-resolved=false
EOF
    arch-chroot /mnt systemctl enable NetworkManager.service
    arch-chroot /mnt systemctl enable avahi-daemon

else
    echo [Match] >/mnt/etc/systemd/network/10-static-${ifport}.network
    echo Name=${ifport} >>/mnt/etc/systemd/network/10-static-${ifport}.network
    echo  >>/mnt/etc/systemd/network/10-static-${ifport}.network
    echo [Network] >>/mnt/etc/systemd/network/10-static-${ifport}.network
    echo Address=$ifaddr/$ifmask >>/mnt/etc/systemd/network/10-static-${ifport}.network
    echo Gateway=$ifgw >>/mnt/etc/systemd/network/10-static-${ifport}.network
    echo DNS=$ifgw $ifdns >>/mnt/etc/systemd/network/10-static-${ifport}.network

    arch-chroot /mnt systemctl enable systemd-networkd
fi

# pacstrap /mnt iw wpa_supplicant 
# arch-chroot cat >/etc/wpa_supplicant/wpa_supplicant-wlan.conf <<EOF
# ctrl_interface=/run/wpa_supplicant
# update_config=1
# EOF
# arch-chroot /mnt wpa_supplicant -B -i wlan -c /etc/wpa_supplicant/wpa_supplicant-wlan.conf

### Kernel
ker=Q352A; kver=5.16.8-1
[ $cpu = amd ] && ker=Q352AMD
[ $server = N ] && ker=${ker}w
echo .......................
echo Install Kernel Q352 ...
arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-${ker}-${kver}-x86_64.pkg.tar.zst
arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/kernel/linux-${ker}-headers-${kver}-x86_64.pkg.tar.zst
arch-chroot /mnt pacman -U --noconfirm /root/linux-${ker}-${kver}-x86_64.pkg.tar.zst /root/linux-${ker}-headers-${kver}-x86_64.pkg.tar.zst
sed -i 's/loglevel=3/loglevel=0 nohz=off idle=poll nosmt clocksource=tsc tsc=reliable tsc=noirqtime hpet=disable no_timer_check nowatchdog intel_pstate=disable apparmor=0/' /mnt/etc/default/grub

cpus=$(lscpu | grep 'Core(s) per socket:' | cut -d ':' -f2)
isocpu=''
[ $cpus -ge 4 ] && [ $server = L ] || [[ $player =~ S ]] && isocpu='isolcpus=3 irqaffinity=0,1,2 '
[ $cpus -ge 6 ] && [ $server = L ] && [[ $player =~ S ]] && isocpu='isolcpus=3,4 irqaffinity=0,1,2,5,6,7 '
sed -i 's/idle=poll /idle=poll '"$isocpu"'/' /mnt/etc/default/grub
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
## server
echo ...............
case $server in
    L)
        echo Install LMS ...
        arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/logitechmediaserver-8.2.0-2-x86_64.pkg.tar.xz
        arch-chroot /mnt pacman -U --noconfirm /root/logitechmediaserver-8.2.0-2-x86_64.pkg.tar.xz
        [ $cpus -ge 4 ] && [[ $player =~ S ]] && sed -i 's/^PIDFile/#PIDFile/;/ExecStart=/iType=idle\nExecStartPost=/usr/bin/taskset -cp 3 $MAINPID' /mnt/usr/lib/systemd/system/logitechmediaserver.service
        [ $cpus -ge 6 ] && [[ $player =~ S ]] && sed -i 's/^PIDFile/#PIDFile/;/ExecStart=/iType=idle\nExecStartPost=/usr/bin/taskset -cp 4 $MAINPID' /mnt/usr/lib/systemd/system/logitechmediaserver.service
        arch-chroot /mnt systemctl enable logitechmediaserver
        ;;
    M)
        echo Install MPD ...
        arch-chroot /mnt pacman -S --noconfirm mpd
        arch-chroot /mnt systemctl enable mpd
        ;;
    R)
        echo Install Roon ...
        arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonserver-1.8.884-1-x86_64.pkg.tar.xz.aa
        arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonserver-1.8.884-1-x86_64.pkg.tar.xz.ab
        arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonserver-1.8.884-1-x86_64.pkg.tar.xz.ac
        arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonserver-1.8.884-1-x86_64.pkg.tar.xz.ad
        cat /mnt/root/roonserver-1.8.884-1-x86_64.pkg.tar.xz.* > /mnt/root/roonserver-1.8.884-1-x86_64.pkg.tar.xz
        arch-chroot /mnt pacman -U --noconfirm /root/roonserver-1.8.884-1-x86_64.pkg.tar.xz
        arch-chroot /mnt systemctl enable roonserver
        ;;
esac

### Install Squeezelite
echo Install alsa-lib ......
arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst
arch-chroot /mnt pacman -U --noconfirm --overwrite '*' /root/alsa-lib-1.1.9-2-x86_64.pkg.tar.zst
arch-chroot /mnt pacman -Sd --noconfirm alsa-utils
echo Install Squeezelite ...
arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/squeezelite-1.9.8.1317-dsd-x86_64.pkg.tar.zst
arch-chroot /mnt pacman -U --noconfirm /root/squeezelite-1.9.8.1317-dsd-x86_64.pkg.tar.zst
sed -i '/ExecStart=/iExecStartPre=/usr/bin/sleep 3' /mnt/usr/lib/systemd/system/squeezelite.service
[ $cpus -ge 4 ] && sed -i '/ExecStart=/iType=idle\nExecStartPost=/usr/bin/taskset -cp 3 $MAINPID' /mnt/usr/lib/systemd/system/squeezelite.service

    [[ $player =~ S ]] && arch-chroot /mnt systemctl enable squeezelite
if  [[ $player =~ A ]]; then
    echo Install Airplay ...
    arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
    arch-chroot /mnt pacman -U --noconfirm /root/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
    arch-chroot /mnt systemctl enable shairport-sync
fi
if  [[ $player =~ R ]]; then
    echo Install Roonbridge ...
    arch-chroot /mnt wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonbridge-1.8.880-1-x86_64.pkg.tar.zst
    arch-chroot /mnt pacman -U --noconfirm /root/roonbridge-1.8.880-1-x86_64.pkg.tar.zst
    arch-chroot /mnt systemctl enable roonbridge
fi

### other setting
arch-chroot /mnt systemctl enable sshd.service
arch-chroot /mnt systemctl enable cpupower.service
echo ........................
echo IO Scheduler setting ...
cat >/mnt/etc/udev/rules.d/60-ioschedulers.rules <<EOF
# set scheduler for NVMe
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
# set scheduler for SSD and eMMC
ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
# set scheduler for rotating disks
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
### install config file
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/timezone.sh >/mnt/usr/bin/timezone.sh
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/sqzlite-cfg.sh >/mnt/usr/bin/sqzlite-cfg.sh
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/nfs-cfg.sh >/mnt/usr/bin/nfs-cfg.sh
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/ether-cfg.sh >/mnt/usr/bin/ether-cfg.sh
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/kernel-cfg.sh >/mnt/usr/bin/kernel-cfg.sh
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/partimnt-cfg.sh >/mnt/usr/bin/partimnt-cfg.sh
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/update_scpt.sh >/mnt/usr/bin/update_scpt.sh
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/player-cfg.sh >/mnt/usr/bin/player-cfg.sh
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/config/config.sh >/mnt/usr/bin/config.sh
chmod +x /mnt/usr/bin/*.sh

# Install ramroot
# arch-chroot /mnt wget -O - https://raw.githubusercontent.com/sam0402/ArchQ/pkg/main/ramroot-2.0.2-1-x86_64.pkg.tar.zst | pacman -U
# sed -i 's/ps_default=no/ps_default=yes/' /mnt/etc/ramroot.conf
# arch-chroot /mnt mkinitcpio -P
echo
echo
echo '*************************************************************'
echo 'Arch Linux is installed. System will reboot after 8 seconds.'
echo '*************************************************************'
sleep 8
reboot
