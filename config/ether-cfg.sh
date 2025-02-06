#!/bin/bash
mkgrub(){
    grub_cfg='/boot/grub/grub.cfg'
    part_boot=$(lsblk -pln -o name,parttypename | grep EFI | awk 'NR==1 {print $1}')
    mount "$part_boot" /mnt
    sleep 2
    os-prober
    grub-mkconfig -o $grub_cfg
    pacman -Q ramroot >/dev/null 2>&1 && sed -i 's/fallback/ramroot/g' $grub_cfg
}
ifmask=24; ifdns=8.8.8.8; ifmtu=1500
ethers=$(ip -o link show | awk '{print $2,$9}' | grep '^en\|^wlan' | sed 's/://')
ifport=$(echo $ethers | cut -d ' ' -f1)
if [ $(echo $ethers | wc -w) -gt 2 ]; then
    ifport=$(dialog --stdout --title "ArchQ $1" \
            --menu "Select network device" 7 0 0 ${ethers}) || exit 1; clear
fi

if echo $ifport | grep -q wlan; then
    iw_conf(){
        # ssid_list=$(iwctl station wlan0 get-networks | awk '{print $1}')
        iw_conf=$(dialog --stdout --title "ArchQ $1" \
        --ok-label "Ok" --form "$ifport setting" 0 28 0 \
        "SSID"      1 1 ""  1 10 28 0 \
        "Password"  2 1 ""  2 10 28 0 ) || exit 1; clear
        iwssid=$(echo $iw_conf | awk '//{print $1 }')
        iwpasswd=$(echo $iw_conf | awk '//{print $2 }')
    }
    iw_conf
    if iwctl --passphrase $iwpasswd station wlan0 connect $iwssid; then
        :
    else
        dialog --stdout --title "ArchQ $1" --pause "\n Connect fail!\n\n Setting $ifport again." 12 0 3 || exit 1; clear
        iw_conf
    fi 
    systemctl enable --now iwd
fi

if [ -f "/etc/systemd/network/10-${ifport}.network" ]; then
    config="/etc/systemd/network/10-${ifport}.network"
    while read line; do
        eval $(grep '=' | sed 's/ /,/g')
    done < $config

    [[ -n $Address ]] && ifip=$(echo $Address | cut -d'/' -f1)
    [[ -n $Address ]] && ifmask=$(echo $Address | cut -d'/' -f2)
    [[ -n $DNS ]] && ifdns=$(echo $DNS | cut -d',' -f2)
    [[ -n $MTUBytes ]] && ifmtu=$(echo $MTUBytes | cut -d',' -f2)
fi

grep -q "IPv6PrivacyExtensions=true\|DHCP=true" $config && v6_o='on' || v6_o='off'

if echo $ifport | grep -q en; then
    ip='D'
    ip=$(dialog --stdout --title "ArchQ $1" --menu "Select IP setting" 7 0 0 S "Static IP" D "DHCP") || exit 1; clear
fi

if [[ $ip == S ]]; then
    ifconfig=$(dialog --stdout \
                --title "ArchQ $1" \
                --ok-label "Ok" \
                --form "Ethernet $ifport IP setting" 10 38 0 \
                "Address" 1 1   "$ifip"     1 10 15 0 \
                "Netmask" 2 1   "$ifmask"   2 10 15 0 \
                "Gateway" 3 1   "$Gateway"  3 10 15 0 \
                "DNS"     4 1   "$ifdns"    4 10 15 0 \
                "MTU"     5 1   "$ifmtu"    5 10 15 0) || exit 1
    clear

    ifaddr=$(echo $ifconfig | cut -d' ' -f1)
    ifmask=$(echo $ifconfig | cut -d' ' -f2)
    ifgw=$(echo $ifconfig | cut -d' ' -f3)
    ifdns=$(echo $ifconfig | cut -d' ' -f4)
    ifmtu=$(echo $ifconfig | cut -d' ' -f5)
else
    DHCP='ipv4'
fi

v6=$(dialog --stdout --title "ArchQ $1" --checklist "Ethernet ${ifport}" 7 0 0 6 IPv6 $v6_o ) || exit 1; clear
if [[ $v6 == '6' ]];then
    v6='on'; DHCP='true'
    sed -i 's/ipv6.disable=1 //g' /etc/default/grub
else
    v6='off'
    grep -q 'ipv6.disable=1' /etc/default/grub || sed -i 's/iomem=relaxed /iomem=relaxed ipv6.disable=1 /' /etc/default/grub
fi
[[ $v6_o != $v6 ]] && mkgrub

ifmac=$(ip link show $ifport | grep ether | awk '{print $2 }')

echo [Match] >$config
echo Name=${ifport} >>$config
echo MACAddress=${ifmac} >>$config
echo  >>$config
echo [Network] >>$config
if [[ $ip == S ]]; then
    echo Address=$ifaddr/$ifmask >>$config
    echo Gateway=$ifgw >>$config
    echo DNS=$ifgw $ifdns >>$config
    [[ $v6 == 'on' ]] && echo "IPv6PrivacyExtensions=true" >>$config
else
    echo DHCP=$DHCP >>$config
fi
echo  >>$config

echo [Link] >>$config
echo NamePolicy=kernel database onboard slot path >>$config
echo MTUBytes=$ifmtu >>$config
