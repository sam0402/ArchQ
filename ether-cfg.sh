#!/bin/bash
ifmask=24; ifdns=8.8.8.8
ethers=$(ip -o link show | awk '{print $2,$9}' | grep '^en' | sed 's/://')
ifport=$(dialog --stdout --title "Ethernet" \
        --menu "Select device" 7 0 0 ${ethers}) || exit 1
clear

if [ -f "/etc/systemd/network/10-static-${ifport}.network" ]; then
    config="/etc/systemd/network/10-static-${ifport}.network"
    while read line; do
        eval $(grep '=' | sed 's/ /,/')
    done < $config

    ifip=$(echo $Address | cut -d'/' -f1)
    ifmask=$(echo $Address | cut -d'/' -f2)
    ifdns=$(echo $DNS | cut -d',' -f2)
    ifmtu=$(echo $MTUBytes | cut -d',' -f2)
fi

[ -z $ifmtu ] && ifmtu=1500
ifconfig=$(dialog --stdout \
            --title "Ethernet" \
            --ok-label "Ok" \
            --form "$ifport IP setting" 10 35 0 \
            "Address" 1 1   "$ifip"     1 10 15 0 \
            "Netmask" 2 1   "$ifmask"   2 10 15 0 \
            "Gateway" 3 1   "$Gateway"  3 10 15 0 \
            "DNS"     4 1   "$ifdns"    4 10 15 0 \
            "MTU"     5 1   "$ifmtu"    5 10 15 0) || exit 1
clear

ifaddr=$(echo $ifconfig | cut -d' ' -f1)
ifmast=$(echo $ifconfig | cut -d' ' -f2)
ifgw=$(echo $ifconfig | cut -d' ' -f3)
ifdns=$(echo $ifconfig | cut -d' ' -f4)
ifmtu=$(echo $ifconfig | cut -d' ' -f5)
ifmac=$(ip link show $ifport | grep ether | awk '{print $2 }')

echo [Match] >/etc/systemd/network/10-static-${ifport}.network
echo Name=${ifport} >>/etc/systemd/network/10-static-${ifport}.network
echo MACAddress=${ifmac} >>/etc/systemd/network/10-static-${ifport}.network
echo  >>/etc/systemd/network/10-static-${ifport}.network
echo [Network] >>/etc/systemd/network/10-static-${ifport}.network
echo Address=$ifaddr/$ifmask >>/etc/systemd/network/10-static-${ifport}.network
echo Gateway=$ifgw >>/etc/systemd/network/10-static-${ifport}.network
echo DNS=$ifgw $ifdns >>/etc/systemd/network/10-static-${ifport}.network
echo  >>/etc/systemd/network/10-static-${ifport}.network
echo [Link] >>/etc/systemd/network/10-static-${ifport}.network
echo MTUBytes=$ifmtu >>/etc/systemd/network/10-static-${ifport}.network