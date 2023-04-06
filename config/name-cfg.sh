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
echo "$user:$password" | chpasswd --root
sh -c "echo $user:$password | chpasswd"
echo "root:$password" | chpasswd --root
sh -c "echo root:$password | chpasswd"
echo "$user $hostname =NOPASSWD: /usr/bin/systemctl poweroff,/usr/bin/systemctl halt,/usr/bin/systemctl reboot,/usr/bin/qboot,/usr/bin/sw" >>/etc/sudoers
###
cat >>/home/${user}/.bashrc <<EOF
\$(uname -r | grep -q Qrip) && PSC=36 || PSC=31
export KVER=\$(uname -r | cut -d- -f3)
alias ...='cd ../../'
alias dir='command ls -lSrah'
alias egrep='egrep --color=auto'
alias grep='grep --color=auto'
alias ll='command ls -l --color=auto -v'
alias ls='command ls --color=auto -v'
alias abcde='eject -t; abcde'
alias poweroff='sudo systemctl poweroff'
alias reboot='sudo systemctl reboot'
alias config='sudo config.sh'
alias qboot='sudo qboot'
alias qrip='yes | sudo qboot 1'
alias qplay='yes | sudo qboot 2'
alias sw='sudo sw'
EOF
sed -i 's/\\h/\\h:\\e[0\;${PSC}m$KVER\\e[m/' /home/${user}/.bashrc
##
rm /root/.bash_profile
/usr/bin/server-cfg.sh
