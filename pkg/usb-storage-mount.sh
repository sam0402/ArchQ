#!/bin/sh
/usr/bin/systemd-mount --no-block --automount=yes --collect \
UUID=$1 `cat /etc/fstab | grep $1 | cut -d' ' -f 2`
