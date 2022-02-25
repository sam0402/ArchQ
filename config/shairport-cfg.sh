#!/bin/bash
config='/etc/shairport-sync.conf'
shAirportConfig ()
{
    config='/etc/shairport-sync.conf'
    if [ ! $(aplay -L | grep ':') ]; then
      echo "No Sound Device" ; exit 1
    fi

    while read line; do
        devs+=${line}' 　 '
    done <<< $(aplay -L | grep ':')

    device=$(dialog --stdout \
                    --title "Airplay" \
                    --menu "Select ouput device" 7 0 0 ${devs}) || exit 1
    clear

    sed -i 's/^\/\?\/\?\toutput_device = ".*/\toutput_device = '"\"$device\""'/' $config
}

WK=$(dialog --stdout --title "ArchQ" --menu "Airplay setting" 7 0 0 C Config E Enable D Disable) || exit 1
clear


case $WK in
  E)
    if [ ! -f $config ]; then
      wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
      pacman -U --noconfirm /root/shairport-sync-3.3.9-1-x86_64.pkg.tar.zst
      shAirportConfig
    fi
      systemctl enable shairport-sync
      systemctl restart shairport-sync
      echo shAirport is started.
    ;;
  D)
    systemctl disable shairport-sync
    systemctl stop shairport-sync
    echo shAirport is stoped.
    ;;
  C)
    shAirportConfig
    systemctl restart shairport-sync
    echo shAirport is restarted.
    ;;
esac
