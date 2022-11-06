 #!/bin/bash
s0=off; a0=off; r0=off
s1=off; a1=off; r1=off
[ $(systemctl is-active squeezelite) = active ] && s0=on
[ $(systemctl is-active shairport-sync) = active ] && a0=on
[ $(systemctl is-active roonbridge) = active ] && r0=on

player=$(dialog --stdout --title "ArchQ $1" \
        --checklist "Active player" 7 0 0 \
        S Squeezelite   $s0 \
        A Airplay       $a0 \
        R Roonbridge    $r0 ) || exit 1
clear

[[ $player =~ S ]] && s1=on
[[ $player =~ A ]] && a1=on
[[ $player =~ R ]] && r1=on

cpus=$(getconf _NPROCESSORS_ONLN)
if [[ $player =~ A ]] && ! pacman -Q shairport-sync >/dev/null 2>&1; then
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /root/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
    # sed -i '/Group=/iNice=-10' /usr/lib/systemd/system/shairport-sync.service
    systemctl daemon-reload
fi
if [[ $player =~ S ]] && ! pacman -Q squeezelite >/dev/null 2>&1; then
    mkdir -p /root/squzlite
    [ -f /root/squzlite/squeezelite-1.9.8.1317-dsd-x86_64.pkg.tar.zst ] || wget -qP /root/squzlite https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/squeezelite-1.9.8.1317-dsd-x86_64.pkg.tar.zst
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/squeezelite-1.9.8.1317-dsd-x86_64.pkg.tar.zst
    pacman -U --noconfirm /root/squzlite/squeezelite-1.9.8.1317-dsd-x86_64.pkg.tar.zst
    # curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/squeezelite.service >/mnt/usr/lib/systemd/system/squeezelite.service
    systemctl daemon-reload
    /usr/bin/sqzlite-cfg.sh
fi

if [[ $s0 != $s1 ]]; then
    if [[ $s1 == on ]]; then
        act+='squeezelite '
        [ $cpus -ge 4 ] && isocpu='isolcpus=1 rcu_nocbs=1 irqaffinity=0,2-7 '
        [ $cpus -ge 6 ] && [ $(systemctl is-active logitechmediaserver) = active ] && isocpu='isolcpus=1,4 rcu_nocbs=1,4 irqaffinity=0,2,3,5-7 '
        sed -i 's/idle=poll /idle=poll '"$isocpu"'/' /etc/default/grub
    else
        inact+='squeezelite '
        sed -i 's/isolcpus=1 rcu_nocbs=1 irqaffinity=0,2-7 //' /etc/default/grub
        sed -i 's/isolcpus=1,4 rcu_nocbs=1,4 irqaffinity=0,2,3,5-7 /isolcpus=1 rcu_nocbs=1 irqaffinity=0,2-7 /' /etc/default/grub
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
fi

if [[ $a0 != $a1 ]]; then
    [[ $a1 == 'on' ]] && act+='shairport-sync ' || inact+='shairport-sync '
fi
if [[ $r0 != $r1 ]]; then
    [[ $r1 == 'on' ]] && act+='roonbridge ' || inact+='roonbridge '
fi

if [[ $act ]]; then
    systemctl enable $act
    systemctl start $act
fi
if [[ $inact ]]; then
    systemctl disable $inact
    systemctl   stop  $inact
fi
