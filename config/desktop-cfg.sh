#!/bin/bash
### Install Desktop (LXDE || LDQT) && TigerVNC
user=$(grep '1000' /etc/passwd | awk -F: '{print $1}')

desktop=$(dialog --stdout --title "ArchQ" --menu "Desktop & VNC :5901" 7 0 0 D LXDE Q LXQt V "VNC only" N Disable) || exit 1
clear

cat /etc/locale.conf >/home/$user/.xinitrc
case $desktop in
    D)
        if ! pacman -Q lxsession >/dev/null 2>&1; then
            pacman -Sy --noconfirm lxdm noto-fonts-cjk tigervnc midori cantata fcitx5-im fcitx5-configtool falkon lxde lxpanel
            pacman -R --noconfirm lxmusic
            sed -i 's/# autologin=.*/autologin='"$user"'/;s/# timeout=.*/timeout=0/' /etc/lxdm/lxdm.conf
        fi
        sed -i 's;^session=.*;session=/usr/bin/startlxde;g' /etc/lxdm/lxdm.conf
        sed -i 's;^session=.*;session=LXDE;g' /home/$user/.vnc/config
        ln -sf /usr/bin/lxterminal /usr/bin/xterm
        systemctl enable --now lxdm vncserver@:1.service
        echo "Enable LXDE & VNC ..."
        ;;
    Q)
        if ! pacman -Q lxqt-session >/dev/null 2>&1; then
            pacman -Sy --noconfirm lxdm noto-fonts-cjk tigervnc midori cantata fcitx5-im fcitx5-configtool falkon \
                lxqt xdg-utils breeze-icons fcitx5-qt fcitx5-chewing fcitx5-mozc
            pacman -R --noconfirm lxqt-powermanagement
            sed -i 's/# autologin=.*/autologin='"$user"'/;s/# timeout=.*/timeout=0/' /etc/lxdm/lxdm.conf
        fi
        sed -i 's;^session=.*;session=/usr/bin/startlxqt;g' /etc/lxdm/lxdm.conf
        sed -i 's;^session=.*;session=lxqt;g' /home/$user/.vnc/config
        ln -sf /usr/bin/qterminal /usr/bin/xterm
        systemctl enable --now lxdm vncserver@:1.service
        echo "LXQt & VNC is enabled."
        ;;
    V)
        systemctl disable --now lxdm
        ;;
    N)
        systemctl disable lxdm vncserver@:1.service
        systemctl stop lxdm vncserver@:1.service
        systemctl set-default multi-user.target
        echo "Desktop & VNC is enabled."
        ;;
esac
echo "XMODIFIERS=@im=fcitx" >/etc/environment
echo "GTK_IM_MODULE=fcitx" >>/etc/environment
echo "QT_IM_MODULE=fcitx" >>/etc/environment

if [ ! -e "/home/$user/Desktop/config.sh" ]; then
    mkdir -p /home/$user/Desktop
    ln -sf /usr/bin/config.sh /home/$user/Desktop/.
    chown -R ${user}: /home/$user/Desktop
fi
# setup vncserver
if [ ! -e "/home/$user/.vnc/passwd" ]; then
    echo $user
    password=$(dialog --stdout --title "ArchQ" --inputbox "Enter VNC password" 0 0) || exit 1
    clear
    : ${password:?"password cannot be empty"}
    password2=$(dialog --stdout --title "ArchQ" --inputbox "Enter VNC password again" 0 0) || exit 1
    clear
    [[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )

    ln /usr/lib/systemd/system/vncserver\@.service /etc/systemd/system/vncserver@:1.service
    echo ":1=$user" >>/etc/tigervnc/vncserver.users
    echo $password | vncpasswd -f >/home/$user/.vnc/passwd
    chmod 600 /home/$user/.vnc/passwd
    chown -R ${user}: /home/$user/.vnc
    systemctl enable --now vncserver@:1.service
    echo "VNC password setuped."
fi
