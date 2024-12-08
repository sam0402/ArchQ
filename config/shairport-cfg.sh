#!/bin/bash
version='4.3.3'
config='/etc/shairport-sync.conf'
name=$(grep -m1 'name = ' $config | awk -F\" '{print $2}')
[ $name = '%H' ] && name=$(uname -n)
(systemctl list-unit-files | grep -q nqptp) && NQPTP=nqptp || NQPTP=''

SelDevice()
{
if [ ! $(aplay -L | grep ':') ]; then
    dialog --title "ArchQ Airplay $1" --msgbox "No Sound Device" 7 30
else
    devs='hw:0,0 　 '
    while read line; do
        devs+=${line}' 　 '
    done <<< $(aplay -L | grep ':')

    device=$(dialog --stdout \
            --title "ArchQ Airplay $1" \
            --menu "Ouput device" 7 0 0 ${devs}) || exit 1; clear
    sed -i 's/^\/\?\/\?\toutput_device = ".*";/\toutput_device = '"\"$device\""';/' $config 
fi
}

SelVer()
{
    airver=$(dialog --stdout --title "ArchQ Airplay $1" --menu "Select version" 7 0 0 1 Classic 2 Multiroom) || exit 1; clear
    wget -qP /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync-${version}-${airver}-x86_64.pkg.tar.zst
    pacman -U --noconfirm /tmp/shairport-sync-${version}-${airver}-x86_64.pkg.tar.zst
    if [[ $airver == '2' ]]; then
      curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/shairport-sync.service >/usr/lib/systemd/system/shairport-sync.service
      wget -qP /tmp https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/nqptp-1.2.5-1-x86_64.pkg.tar.zst
      pacman -U --noconfirm /tmp/nqptp-1.2.5-1-x86_64.pkg.tar.zst
    else
      systemctl disable --now nqptp
      pacman -R --noconfirm nqptp
    fi
    isocpu=$(($(getconf _NPROCESSORS_ONLN)-1))
    sed -i '/Install/iNice=-20\nAllowedCPUs='"$isocpu"'\n' /usr/lib/systemd/system/shairport-sync.service
    echo "Airplay $airver installed."
}

Config()
{
  a0=off; a1=off; v1=off
  volctl=$(grep ignore_volume_control $config | awk -F\" '{print $2}')
  [ $volctl = yes ] && v0=off || v0=on
  [ $(systemctl is-active shairport-sync) = active ] && a0=on

  SEL=$(dialog --stdout --title "ArchQ Airplay $1" \
          --checklist "Configure" 7 0 0 \
          V "Volume Control"  $v0 \
          A Active            $a0 ) || exit 1; clear
  [[ $SEL =~ V ]] && v1=on
  [[ $SEL =~ A ]] && a1=on

  if [[ $v0 != $v1 ]] && [[ $v1 == 'off' ]]; then
      sed -i 's/^\/\?\/\?\tignore_volume_control = "no";/\tignore_volume_control = "yes";/' $config
      echo "Turn off volume control."
  else
      sed -i 's/^\/\?\/\?\tignore_volume_control = "yes";/\tignore_volume_control = "no";/' $config
      echo "Turn on volume control."
  fi
  if [[ $a0 != $a1 ]]; then
    if [[ $a1 == 'on' ]]; then
        systemctl enable $NQPTP shairport-sync
        systemctl start $NQPTP shairport-sync
    else
        systemctl disable shairport-sync $NQPTP
        systemctl stop shairport-sync $NQPTP
    fi
  fi
}

Name()
{
  name=$(dialog --stdout \
      --title "ArchQ Airplay $1" \
      --ok-label "Ok" \
      --form "Change name" 0 20 0 \
      ""  1 1  "$name" 1 0 20 0  ) || exit 1; clear

  sed -i 's/^\/\?\/\?\tname = ".*";/\tname = '"\"$name\""';/1' $config
}

WK=$(dialog --stdout --title "ArchQ $1" --menu "Airplay configure" 7 0 0 \
    S "Sound Card" \
    A "Volume & Active" \
    N "Name: $name" ) || exit 1; clear

case $WK in
  S)
      SelDevice
      systemctl enable $NQPTP shairport-sync
      systemctl restart $NQPTP shairport-sync
      echo shAirport is started.
    ;;
  A)
    Config
    ;;
  N)
    Name
    systemctl restart shairport-sync
    echo shAirport is started.
    ;;
  V)
    SelVer
    ;;
esac