#!/bin/bash
### Install Desktop (LXDE || LDQT) && TigerVNC
user=$(ls /home)

desktop=$(dialog --stdout --title "ArchQ" --menu "Desktop & VNC :5901" 7 0 0 D LXDE Q LXQt N Disable) || exit 1

cat /etc/locale.conf >/home/$user/.xinitrc
case $desktop in
    D)
        lxd="lxde lxdm lxpanel"
        if [[ ! $(pacman -Q lxdm | cut -f1) ]]; then
            pacman -Scc --noconfirm
            pacman -Syy --noconfirm
            pacman -S --noconfirm noto-fonts-cjk tigervnc midori cantata fcitx5-im fcitx5-configtool $lxd
            sed -i 's;^# session=/usr/bin/startlxde;session=/usr/bin/startlxde;g' /etc/lxdm/lxdm.conf
        fi
        systemctl disable sddm; systemctl stop sddm
        systemctl enable lxdm vncserver@:1.service
        systemctl start lxdm vncserver@:1.service

        echo "Enable LXDE & VNC ..."
        ;;
    Q)
        lxd="lxqt sddm xdg-utils breeze-icons fcitx5-qt fcitx5-chewing fcitx5-mozc"
        if [[ ! $(pacman -Q sddm | cut -f1) ]]; then
            pacman -Scc --noconfirm
            pacman -Syy --noconfirm
            pacman -S --noconfirm noto-fonts-cjk tigervnc midori cantata fcitx5-im fcitx5-configtool $lxd
        fi
        systemctl disable lxdm; systemctl stop lxdm
        systemctl enable sddm vncserver@:1.service
        systemctl start sddm vncserver@:1.service

        echo "LXQt & VNC is enabled."
        ;;
    N)
        systemctl disable lxdm sddm vncserver@:1.service
        systemctl stop lxdm sddm vncserver@:1.service
        echo "Desktop & VNC is enabled."
        ;;
esac
echo "XMODIFIERS=@im=fcitx" >/etc/environment
echo "GTK_IM_MODULE=fcitx" >>/etc/environment
echo "QT_IM_MODULE=fcitx" >>/etc/environment

if [ ! -e "/home/$user/Desktop/config.sh" ]; then
    ln -sf /usr/bin/qterminal /usr/bin/xterm
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

    cp /usr/lib/systemd/system/vncserver\@.service /etc/systemd/system/vncserver@:1.service
    echo ":1=$user" >>/etc/tigervnc/vncserver.users
    mkdir -p /home/$user/.vnc
    echo $password | vncpasswd -f >/home/$user/.vnc/passwd
    chmod 600 /home/$user/.vnc/passwd
    chown -R ${user}: /home/$user/.vnc
    systemctl enable vncserver@:1.service
    systemctl start vncserver@:1.service
    echo "VNC password setuped."
fi
