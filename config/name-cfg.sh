#!/bin/bash
password(){
    password=$(dialog --stdout --title "ArchQ" --inputbox "Enter admin password" 0 0) || exit 1; clear
    if [[ -z "$password" ]];then
        dialog --stdout --title "ArchQ" --pause "\n Passwd cannot be empty.\n\n Setting password again." 12 0 3 || exit 1; clear
        password
    fi
    password2=$(dialog --stdout --title "ArchQ" --inputbox "Enter admin password again" 0 0) || exit 1; clear
    if [[ "$password" != "$password2" ]]; then
        dialog --stdout --title "ArchQ" --pause "\n Passwd did not match.\n\n Setting password again." 12 0 3 || exit 1; clear
        password
    fi
}

hostname=$(dialog --stdout --title "ArchQ" --inputbox "Enter hostname" 0 0) || exit 1; clear
if [ -z "$hostname" ];then
    dialog --stdout --title "ArchQ" --pause "\n Hostname cannot be empty.\n\n Default will be 'ArchQ'." 12 0 3 || exit 1; clear
    hostname=ArchQ
    hostname=$(dialog --stdout --title "ArchQ" --inputbox "Enter hostname again" 0 0) || exit 1; clear
fi

user=$(dialog --stdout --title "ArchQ" --inputbox "Enter admin username" 0 0) || exit 1; clear
if [ -z "$user" ];then
    dialog --stdout --title "ArchQ" --pause "\n Username cannot be empty.\n\n Default will be 'archq'." 12 0 3 || exit 1; clear
    user=archq
    user=$(dialog --stdout --title "ArchQ" --inputbox "Enter admin username again" 0 0) || exit 1; clear
fi

password

### Setting
echo "${hostname}" > /etc/hostname
useradd -mU "$user"
usermod -aG wheel $user
echo "$user $hostname =NOPASSWD: /usr/bin/systemctl poweroff,/usr/bin/systemctl halt,/usr/bin/systemctl reboot,/usr/bin/qboot,/usr/bin/sw" >>/etc/sudoers
/usr/bin/server-cfg.sh