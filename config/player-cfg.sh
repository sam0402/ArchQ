 #!/bin/bash
s0=off; a0=off; r0=off
s1=off; a1=off; r1=off
[ $(systemctl is-active squeezelite) = active ] && s0=on
[ $(systemctl is-active shairport-sync) = active ] && a0=on
[ $(systemctl is-active roonbridge) = active ] && r0=on

player=$(dialog --stdout --title "ArchQ" \
        --checklist "Active player" 7 0 0 \
        S Squeezelite   $s0 \
        A Airplay       $a0 \
        R Roonbridge    $r0 )
clear

[[ $player =~ S ]] && s1=on
[[ $player =~ A ]] && a1=on
[[ $player =~ R ]] && r1=on

if [[ $player =~ A && ! -f $config ]]; then
        wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
        pacman -U --noconfirm /root/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
fi

if [[ $s0 != $s1 ]]; then
        [[ $s1 == 'on' ]] && act='squeezelite ' || inact='squeezelite '
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
