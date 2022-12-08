#!/bin/bash
hostname=$(uname -n)
pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm nginx php-sqlite php-gd php-fpm php-intl imagemagick libwmf libjxl mpc which avahi
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd-light-0.23.9-3-x86_64.pkg.tar.zst
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/mpd_cdrom-1.0.0-1-any.pkg.tar.zst
wget -qP /root https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/rompr-1.61-1-any.pkg.tar.zst
pacman -U --noconfirm /root/mpd-light-0.23.9-3-x86_64.pkg.tar.zst /root/mpd_cdrom-1.0.0-1-any.pkg.tar.zst /root/rompr-1.61-1-any.pkg.tar.zst

### Setup RompR
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
sed -i '$i include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
curl -sL https://raw.githubusercontent.com/sam0402/ArchQ/main/pkg/rompr_nginx >/etc/nginx/sites-available/rompr
sed -i 's/hostname/'"${hostname,,}"'/' /etc/nginx/sites-available/rompr
sed -i 's/max_execution_time =.*/max_execution_time = 1800/;s/post_max_size =.*/post_max_size = 256M/;s/upload_max_filesize =.*/upload_max_filesize = 10M/;s/max_file_uploads =.*/max_file_uploads = 200/' /etc/php/php.ini
sed -i 's/;extension=pdo_sqlite/extension=pdo_sqlite/;s/;extension=gd/extension=gd/;s/;extension=intl/extension=intl/' /etc/php/php.ini

ln -s /etc/nginx/sites-available/rompr /etc/nginx/sites-enabled/rompr
chmod 644 /etc/nginx/sites-enabled/rompr

if [ -d /opt/logitechmediaserver ]; then
    mv /var/lib/mpd /opt/logitechmediaserver/
    ln -s /opt/logitechmediaserver/mpd /var/lib/mpd
fi
if [ -d /var/roon ]; then
    mv /var/lib/mpd /var/roon/
    ln -s /var/roon/mpd /var/lib/mpd
fi
