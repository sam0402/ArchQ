#!/bin/bash
c_red_b=$'\e[1;38;5;196m'
c_gray=$'\e[0;37m'
c_write=$'\e[m'

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
ethers=''
while read -r line; do
    if echo $line | grep -q UP; then
        if_status=$(ip -o addr| grep ${line%% *}| awk '{print $4}'| cut -d'/' -f1| head -n 1)
        [ -z $if_status ] && line="${line%% *} DHCP/NoIP" || line="${line%% *} ""$if_status"
    fi
    ethers+=' '$line
done <<< $(ip -o link show | awk '{print $2,$9}' | grep '^en\|^wlan' | sed 's/://')
# ethers=$(ip -o link show | awk '{print $2,$9}' | grep '^en\|^wlan' | sed 's/://')

ifport=$(echo $ethers | cut -d ' ' -f1)

vpn=$(ip -o addr | grep tailscale0 | awk '{print $4}' | cut -d'/' -f1 | head -n 1)
[[ -z $vpn ]] && vpn="DOWN"

MENU='I "Static IP" D "DHCP"'
if [ $(echo $ethers | wc -w) -gt 2 ]; then
    MENU+=' S "DHCP Server" '
    ifport=$(dialog --stdout --title "ArchQ $1" \
            --menu "Select network device" 7 0 0 ${ethers} Tailscale ${vpn}) || exit 1; clear
fi

### Tailscale setup
if [[ ${ifport} == "Tailscale" ]]; then
    if ! systemctl is-active tailscaled >/dev/null 2>&1; then
        if ! pacman -Q tailscale >/dev/null 2>&1; then
            wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/tailscale-1.80.3-1-x86_64.pkg.tar.zst
            pacman -U --noconfirm /tmp/tailscale-1.80.3-1-x86_64.pkg.tar.zst
            systemctl enable --now tailscaled
            echo -e ${c_gray}
            tailscale up
            echo -e ${c_write}
            exit 0
        fi
        systemctl enable --now tailscaled
    else
        systemctl disable --now tailscaled
    fi
    sleep 3
    vpn=$(ip -o addr | grep tailscale0 | awk '{print $4}' | cut -d'/' -f1)
    [[ -z $vpn ]] && echo "Tailscale is DOWN." || echo "Tailscale IP: $vpn"
    exit 0
fi

### Wireless SSID setup
if [[ ${ifport:0:4} == "wlan" ]] ; then
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

if [[ ${ifport:0:2} == "en" ]]; then
    ip='D'
    exec='dialog --stdout --title "ArchQ $1" --menu "Select IP setting" 7 0 0 '$MENU
    ip=$(eval $exec) || exit 1; clear
fi

### DHCP Server
if [[ $ip == S ]]; then
    if ! pacman -Q dhcp >/dev/null 2>&1 ; then
        wget -P /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/dhcp-4.4.2.P1-4-x86_64.pkg.tar.zst
        pacman -U --noconfirm /tmp/*.pkg.tar.zst
    fi

    echo [Match] >$config
    echo Name=${ifport} >>$config
    echo  >>$config
    echo [Network] >>$config
    echo Address=10.10.10.0/27 >>$config
    echo Gateway=10.10.10.1 >>$config

    cat >/etc/dhcpd.conf <<EOF
default-lease-time 600;
max-lease-time 7200;
authoritative;
subnet 10.10.10.0 netmask 255.255.255.224 {
  range 10.10.10.10 10.10.10.20;
  option routers 10.10.10.1;
  option broadcast-address 10.10.10.31;
  option domain-name-servers 10.10.10.1, 8.8.8.8;
#  option domain-name "archq.local";
}
EOF
    echo "Configure the ${ifport} as a DHCP server."
    systemctl enable dhcpd4
    echo -n "Reboot to active DHCP Server [Y/n]?"
    input=''; read input
    [[ -z $input || $input = y ]] && reboot
    exit 0
fi

### Static IP setup
if [[ $ip == I ]]; then
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
echo  >>$config
echo [Network] >>$config
if [[ $ip == I ]]; then
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
echo "The $ifport is set up."