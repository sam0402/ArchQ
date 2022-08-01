#!/bin/bash
config='/etc/shairport-sync.conf'
name=$(grep -m1 'name = ' $config | awk -F\" '{print $2}')
[ $name = '%H' ] && name=$(uname -n)

SelDevice()
{
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

    sed -i 's/^\/\?\/\?\toutput_device = ".*";/\toutput_device = '"\"$device\""';/' $config 
}

Config()
{
  a0=off; a1=off; v1=off
  volctl=$(grep ignore_volume_control $config | awk -F\" '{print $2}')
  [ $volctl = yes ] && v0=off || v0=on
  [ $(systemctl is-active shairport-sync) = active ] && a0=on

  SEL=$(dialog --stdout --title "ArchQ $1" \
          --checklist "Configure" 7 0 0 \
          V "Volume Control"  $v0 \
          A Active            $a0 ) || exit 1
  clear
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
        systemctl enable nqptp shairport-sync
        systemctl start nqptp shairport-sync
    else
        systemctl disable shairport-sync nqptp
        systemctl stop shairport-sync nqptp
    fi
  fi
}

Name()
{
  name=$(dialog --stdout \
      --title "Airplay" \
      --ok-label "Ok" \
      --form "Change name" 0 20 0 \
      ""  1 1  "$name" 1 0 20 0  ) || exit 1

  sed -i 's/^\/\?\/\?\tname = ".*";/\tname = '"\"$name\""';/1' $config
}

WK=$(dialog --stdout --title "ArchQ $1" --menu "Airplay configure" 7 0 0 \
    S "Sound Card" \
    V "Volume & Active" \
    N "Name: $name") || exit 1
clear

case $WK in
  S)
      SelDevice
      systemctl enable nqptp shairport-sync
      systemctl restart nqptp shairport-sync
      echo shAirport is started.
    ;;
  V)
    Config
    ;;
  N)
    Name
    systemctl restart shairport-sync
    echo shAirport is started.
    ;;
esac