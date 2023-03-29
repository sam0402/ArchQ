 #!/bin/bash
s0=off; a0=off; r0=off
s1=off; a1=off; r1=off
[ $(systemctl is-active squeezelite) = active ] && s0=on
[ $(systemctl is-active shairport-sync) = active ] && a0=on
[ $(systemctl is-active roonbridge) = active ] && r0=on

player=$(dialog --stdout --title "ArchQ $1" --checklist "Active player" 7 0 0 \
        S Squeezelite   $s0 \
        A Airplay       $a0 \
        R Roonbridge    $r0 ) || exit 1; clear

[[ $player =~ S ]] && s1=on
[[ $player =~ A ]] && a1=on
[[ $player =~ R ]] && r1=on

cpus=$(getconf _NPROCESSORS_ONLN)
if [[ $player =~ S ]] && ! pacman -Q squeezelite >/dev/null 2>&1; then
    /usr/bin/sqzlite-cfg.sh
fi
if [[ $player =~ A ]] && ! pacman -Q shairport-sync >/dev/null 2>&1; then
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /root/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
    sed -i '/Group=/iNice=-20\nAllowedCPUs=4' /usr/lib/systemd/system/shairport-sync.service
    systemctl daemon-reload
fi
if [[ $player =~ R ]] && ! pacman -Q roonbridge >/dev/null 2>&1; then
    wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonbridge-1.8.880-1-x86_64.pkg.tar.zst
    pacman -U --noconfirm /root/roonbridge-1.8.880-1-x86_64.pkg.tar.zst
    sed -i '/Group=/iNice=-20\nAllowedCPUs=4' /usr/lib/systemd/system/roonbridge-1.8.880-1-x86_64.pkg.tar.zst
    systemctl daemon-reload
fi
if [[ $s0 != $s1 ]]; then
    if [[ $s1 == on ]]; then
        act+='squeezelite '
        iso_1st=$((cpus-1)); iso_2nd=$((cpus/2-1))
        isocpu="isolcpus=$iso_1st rcu_nocbs=$iso_1st "
        [ $cpus -ge 4 ] && isocpu="isolcpus=$iso_1st rcu_nocbs=$iso_1st "
        [ $cpus -ge 6 ] && [ $(systemctl is-active logitechmediaserver) = active ] && isocpu="isolcpus=$iso_1st,$iso_2nd rcu_nocbs=$iso_1st,$iso_2nd "
        sed -i 's/idle=poll/idle=poll '"$isocpu"'/' /etc/default/grub
    else
        inact+='squeezelite '
        sed -i 's/idle=poll '"$isocpu"'//' /etc/default/grub
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
fi

if [[ $a0 != $a1 ]]; then
    (systemctl list-unit-files | grep -q nqptp) && AIRPLAY='nqptp shairport-sync' || AIRPLAY='shairport-sync'
    [[ $a1 == 'on' ]] && act+=$AIRPLAY || inact+=$AIRPLAY
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