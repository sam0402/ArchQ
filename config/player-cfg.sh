 #!/bin/bash
grub_cfg='/boot/grub/grub.cfg'
mkgrub(){
    if lsblk -pln -o name,partlabel | grep -q Microsoft; then
        part_boot=$(lsblk -pln -o name,parttypename | grep EFI | awk 'NR==1 {print $1}')
        mount "$part_boot" /mnt
        sleep 2
        os-prober | grep -q Windows || umount /mnt
    fi
    grub-mkconfig -o $grub_cfg
    pacman -Q ramroot >/dev/null 2>&1 && sed -i 's/fallback/ramroot/g' $grub_cfg
}
s0=off; a0=off; r0=off; h0=off
s1=off; a1=off; r1=off; h1=off
[ $(systemctl is-active squeezelite) = active ] && s0=on
[ $(systemctl is-active shairport-sync) = active ] && a0=on
[ $(systemctl is-active roonbridge) = active ] && r0=on
[ $(systemctl is-active networkaudio) = active ] && h0=on

player=$(dialog --stdout --title "ArchQ $1" --checklist "Active player" 7 0 0 \
        S Squeezelite   $s0 \
        A Airplay       $a0 \
        R Roonbridge    $r0 \
        H "HQPlayer NAA" $h0 ) || exit 1; clear

[[ $player =~ S ]] && s1=on
[[ $player =~ A ]] && a1=on
[[ $player =~ R ]] && r1=on
[[ $player =~ H ]] && h1=on

cpus=$(getconf _NPROCESSORS_ONLN)
if [[ $player =~ S ]] && ! pacman -Q squeezelite >/dev/null 2>&1; then
    /usr/bin/sqzlite-cfg.sh
fi
if [[ $player =~ A ]] && ! pacman -Q shairport-sync >/dev/null 2>&1; then
    wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync-4.3.3-2-x86_64.pkg.tar.zst
    wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/nqptp-1.2.5-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /tmp/shairport-sync-4.3.3-2-x86_64.pkg.tar.zst /tmp/nqptp-1.2.5-1-x86_64.pkg.tar.zst
    curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync.service >/usr/lib/systemd/system/shairport-sync.service
    sed -i 's/^\/\?\/\?\toutput_device = ".*";/\toutput_device = \"hw:0,0\";/;s/^\/\?\/\?\toutput_format = ".*";/\toutput_format = "S32_LE";/' /etc/shairport-sync.conf
    sed -i 's/^\/\?\/\?\tperiod_size = <.*>;/\tperiod_size = 78;/;s/^\/\?\/\?\tbuffer_size = <.*>;/\tbuffer_size = 468;/' /etc/shairport-sync.conf
    sed -i 's/^\/\?\/\?\tresync_threshold_in_seconds = 0.050;/\tresync_threshold_in_seconds = 0.025;/' /etc/shairport-sync.conf
    sed -i 's/Requires=/Requires=nqptp.service /' /usr/lib/systemd/system/shairport-sync.service
    sed -i '/Install/iNice=-20\n' /usr/lib/systemd/system/shairport-sync.service
    sed -i 's|ExecStart=|ExecStart=/usr/bin/pagecache-management.sh |' /usr/lib/systemd/system/shairport-sync.service
    systemctl daemon-reload
    systemctl enable --now nqptp shairport-sync
    /usr/bin/shairport-cfg.sh ; exit 0
fi
if [[ $player =~ R ]] && ! pacman -Q roonbridge >/dev/null 2>&1; then
    wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonbridge-1.8.1125-2-x86_64.pkg.tar.zst
    pacman -U --noconfirm /tmp/roonbridge-1.8.1125-2-x86_64.pkg.tar.zst
    systemctl daemon-reload
fi
if [[ $player =~ H ]] && ! pacman -Q hqplayer-network-audio-daemon >/dev/null 2>&1; then
    wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/hqplayer-network-audio-daemon-4.4.0-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /tmp/hqplayer-network-audio-daemon-4.4.0-1-x86_64.pkg.tar.zst
    systemctl daemon-reload
fi

if [[ $s0 != $s1 ]]; then
    if [[ $s1 == on ]]; then
        act+='squeezelite '
        iso_1st=$((cpus-1)); iso_2nd=$((cpus/2-1))
        isocpu="isolcpus=$iso_1st rcu_nocbs=$iso_1st "
        [ $cpus -ge 4 ] && isocpu="isolcpus=$iso_1st rcu_nocbs=$iso_1st "
        [ $cpus -ge 6 ] && [ $(systemctl is-active logitechmediaserver) = active ] && isocpu="isolcpus=$iso_1st,$iso_2nd rcu_nocbs=$iso_1st,$iso_2nd "
        sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="'"$isocpu"'"/' /etc/default/grub
    else
        inact+='squeezelite '
        sed -i 's/'"$isocpu"'//' /etc/default/grub
    fi
    mkgrub
fi

if [[ $a0 != $a1 ]]; then
    (systemctl list-unit-files | grep -q nqptp) && AIRPLAY='nqptp shairport-sync ' || AIRPLAY='shairport-sync '
    [[ $a1 == 'on' ]] && act+=$AIRPLAY || inact+=$AIRPLAY
fi
if [[ $r0 != $r1 ]]; then
    [[ $r1 == 'on' ]] && act+='roonbridge ' || inact+='roonbridge '
fi
if [[ $s0 != $s1 ]]; then
    [[ $s1 == 'on' ]] && act+='squeezelite ' || inact+='squeezelite '
fi
if [[ $h0 != $h1 ]]; then
    [[ $h1 == 'on' ]] && act+='networkaudio ' || inact+='networkaudio '
fi
if [[ $act ]]; then
   systemctl enable --now $act
fi
if [[ $inact ]]; then
   systemctl disable --now $inact
fi