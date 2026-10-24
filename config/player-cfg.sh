#!/bin/bash
grub_cfg='/boot/grub/grub.cfg'
naa_deb=$(curl -sL --connect-timeout 2 https://www.signalyst.com/bins/naa/linux/bookworm/ | grep "networkaudiod_5" | grep _amd64.deb | tail -n1 | awk -F'"' '{print $8}')
naa_ver=${naa_deb#*_}; naa_ver=${naa_ver%-*}

cpus=$(getconf _NPROCESSORS_CONF)
[ "$(cat /sys/devices/system/cpu/smt/active 2>/dev/null)" = 1 ] && cpus=$((cpus/2))
iso_1st=$((cpus-1)); iso_2nd=$((cpus/2))

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

s0=off; a0=off; r0=off; h0=off; p0=off
systemctl is-active --quiet squeezelite    && s0=on
systemctl is-active --quiet shairport-sync && a0=on
systemctl is-active --quiet roonbridge     && r0=on
systemctl is-active --quiet networkaudio   && h0=on
systemctl is-active --quiet pcmrecv        && p0=on

player=$(dialog --stdout --title "ArchQ $1" --checklist "Active player" 7 0 0 \
        P Pcmrecv       $p0 \
        S Squeezelite   $s0 \
        A Airplay       $a0 \
        R Roonbridge    $r0 \
        H "HQPlayer NAA $naa_ver" $h0 ) || exit 1; clear

p1=off; s1=off; a1=off; r1=off; h1=off
[[ $player =~ P ]] && p1=on
[[ $player =~ S ]] && s1=on
[[ $player =~ A ]] && a1=on
[[ $player =~ R ]] && r1=on
[[ $player =~ H ]] && h1=on

for p in $player; do
    case ${p//\"/} in
        P)
            pacman -Q pcmrecv >/dev/null 2>&1 || {
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/pcmrecv-0.5-1-x86_64.pkg.tar.zst
                pacman -U --noconfirm /tmp/pcmrecv-0.5-1-x86_64.pkg.tar.zst
            }
            ;;
        S)
            pacman -Q squeezelite >/dev/null 2>&1 || /usr/bin/sqzlite-cfg.sh
            ;;
        A)
            if ! pacman -Q shairport-sync >/dev/null 2>&1; then
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync-4.3.3-2-x86_64.pkg.tar.zst \
                             https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/nqptp-1.2.5-1-x86_64.pkg.tar.zst
                pacman -U --noconfirm /tmp/shairport-sync-4.3.3-2-x86_64.pkg.tar.zst /tmp/nqptp-1.2.5-1-x86_64.pkg.tar.zst
                curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync.service >/usr/lib/systemd/system/shairport-sync.service
                sed -i 's/^\/\?\/\?\toutput_device = ".*";/\toutput_device = \"hw:0,0\";/' /etc/shairport-sync.conf
                sed -i 's/^\/\?\/\?\tperiod_size = <.*>;/\tperiod_size = 78;/;s/^\/\?\/\?\tbuffer_size = <.*>;/\tbuffer_size = 468;/' /etc/shairport-sync.conf
                sed -i 's/^\/\?\/\?\tresync_threshold_in_seconds = 0.050;/\tresync_threshold_in_seconds = 0.025;/' /etc/shairport-sync.conf
                sed -i '/Install/iNice=-20\n' /usr/lib/systemd/system/shairport-sync.service
                sed -i 's|ExecStart=|ExecStart=/usr/bin/pagecache-management.sh |' /usr/lib/systemd/system/shairport-sync.service
                systemctl daemon-reload
                systemctl enable --now nqptp shairport-sync
                /usr/bin/shairport-cfg.sh; exit 0
            fi
            ;;
        R)
            pacman -Q roonbridge >/dev/null 2>&1 || {
                wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/roonbridge-1.8.1125-2-x86_64.pkg.tar.zst
                pacman -U --noconfirm /tmp/roonbridge-1.8.1125-2-x86_64.pkg.tar.zst
                systemctl daemon-reload
            }
            ;;
        H)
            [ ! -f /usr/bin/networkaudiod ] && {
                [ -z "$naa_deb" ] && naa_deb=$(curl -sL https://www.signalyst.com/bins/naa/linux/bookworm/ | grep "networkaudiod_5" | grep _amd64.deb | tail -n1 | awk -F'"' '{print $8}')
                curl -L "https://www.signalyst.com/bins/naa/linux/bookworm/$naa_deb" | bsdtar xf - -C /tmp
                mkdir -p /tmp/naa
                bsdtar Jxf /tmp/data.tar.xz -C /tmp/naa
                install -Dm644 "/tmp/naa/etc/default/networkaudiod" "/etc/default/networkaudiod"
                install -Dm644 "/tmp/naa/etc/networkaudiod/networkaudiod.xml" "/etc/networkaudiod/networkaudiod.xml"
                install -Dm644 "/tmp/naa/lib/systemd/system/networkaudiod.service" "/usr/lib/systemd/system/networkaudio.service"
                install -Dm644 "/tmp/naa/usr/share/doc/networkaudiod/copyright" "/usr/share/licenses/networkaudiod/COPYING"
                install -Dm755 "/tmp/naa/usr/sbin/networkaudiod" "/usr/bin/networkaudiod"
                rm -rf /tmp/naa /tmp/data.tar.xz
            }
            ;;
    esac
done

systemctl list-unit-files 2>/dev/null | grep -q nqptp && airplay='nqptp shairport-sync' || airplay='shairport-sync'

for item in "$s0:$s1:squeezelite" "$p0:$p1:pcmrecv" "$a0:$a1:$airplay" "$r0:$r1:roonbridge" "$h0:$h1:networkaudio"; do
    IFS=':' read -r old new svc <<< "$item"
    case "$old:$new" in
        off:on) act+="$svc " ;;
        on:off) inact+="$svc " ;;
    esac
done

case "$s0$p0" in
    "$s1$p1") ;;
    *)
        cmdline=$(grep -E '^[[:space:]]*GRUB_CMDLINE_LINUX=' /etc/default/grub | tail -1)
        cmdline="${cmdline#*\"}"
        cmdline="${cmdline%\"}"
        cmdline=$(echo "$cmdline" | sed -E 's/(^|[[:space:]])(isolcpus|rcu_nocbs)=[^[:space:]]*/ /g;s/^[[:space:]]+//;s/[[:space:]]+$//')
        case "$s1:$p1" in
            on:*|*:on)
                isocpu="isolcpus=$iso_1st rcu_nocbs=$iso_1st"
                [ $cpus -ge 6 ] && [ "$s1" = on ] && systemctl is-active --quiet lyrionmusicserver && isocpu="isolcpus=$iso_1st,$iso_2nd rcu_nocbs=$iso_1st,$iso_2nd"
                cmdline="${cmdline:+$cmdline }$isocpu"
                ;;
            off:off)
                ;;
        esac
        sed -i 's|^[[:space:]]*GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="'"$cmdline"'"|' /etc/default/grub
        mkgrub
        ;;
esac

[ -n "$act" ] && systemctl enable --now $act
[ -n "$inact" ] && systemctl disable --now $inact