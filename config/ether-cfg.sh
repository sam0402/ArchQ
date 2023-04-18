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

[ $DHCP == 'true' ] && v6=on || v6=off
ip=$(dialog --stdout --title "ArchQ $1" --menu "Select IP setting" 7 0 0 S "Static IP" D "DHCP") || exit 1; clear
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
    v6=$(dialog --stdout --title "ArchQ $1" --checklist "DHCP ${ifport}" 7 0 0 6 IPv6 $v6 ) || exit 1; clear
    if [[ $v6 == '6' ]];then
        DHCP='true'
        sed -i 's/ipv6.disable=1 //g' /etc/default/grub
    else
        DHCP='ipv4'
        grep -q 'ipv6.disable=1' /etc/default/grub || sed -i 's/iomem=relaxed /iomem=relaxed ipv6.disable=1 /' /etc/default/grub
    fi
    mkgrub
fi

ifmac=$(ip link show $ifport | grep ether | awk '{print $2 }')

echo [Match] >/etc/systemd/network/10-${ifport}.network
echo Name=${ifport} >>/etc/systemd/network/10-${ifport}.network
echo MACAddress=${ifmac} >>/etc/systemd/network/10-${ifport}.network
echo  >>/etc/systemd/network/10-${ifport}.network
echo [Network] >>/etc/systemd/network/10-${ifport}.network
if [[ $ip == S ]]; then
    echo Address=$ifaddr/$ifmask >>/etc/systemd/network/10-${ifport}.network
    echo Gateway=$ifgw >>/etc/systemd/network/10-${ifport}.network
    echo DNS=$ifgw $ifdns >>/etc/systemd/network/10-${ifport}.network
else
    echo DHCP=$DHCP >>/etc/systemd/network/10-${ifport}.network
    echo "# IPv6PrivacyExtensions=true" >>/etc/systemd/network/10-${ifport}.network
fi
echo  >>/etc/systemd/network/10-${ifport}.network
echo [Link] >>/etc/systemd/network/10-${ifport}.network
echo NamePolicy=kernel database onboard slot path >>/etc/systemd/network/10-${ifport}.network
echo MTUBytes=$ifmtu >>/etc/systemd/network/10-${ifport}.network
