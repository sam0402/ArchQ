#!/bin/bash
TimeZoneOptionsByRegion () 
{
    options=$(cd /usr/share/zoneinfo/$1 && find . | sed "s|^\./||" | sed "s/^\.//" | sed '/^$/d')
}

TimeZoneRegions () 
{
    regions=$(find /usr/share/zoneinfo/. -maxdepth 1 -type d | cut -d "/" -f6 | sed '/^$/d')
}

TimeZoneSelectionMenu () 
{
    TimeZoneRegions
    regionsArray=()
    while read name; do
        regionsArray+=($name "")
    done <<< "$regions"

    region=$(dialog --stdout \
                    --title "Timezones" \
                    --backtitle " " \
                    --ok-label "Next" \
                    --no-cancel \
                    --menu "Select a continent or ocean from the menu:" \
                    20 30 30 \
                    "${regionsArray[@]}")

    TimeZoneOptionsByRegion $region

    optionsArray=()
    while read name; do
        offset=$(TZ="$region/$name" date +%z | sed "s/00$/:00/g")
        optionsArray+=($name "($offset)")
    done <<< "$options"

    tz=$(dialog --stdout \
                --title "Timezones" \
                --backtitle " " \
                --menu "Select your timezone in ${region}:" \
                20 40 30 \
                "${optionsArray[@]}")

    if [[ -z "${tz// }" ]]; then
        TimeZoneSelectionMenu
    else
        echo "/usr/share/zoneinfo/$region/$tz"
    fi
}

tZone="$(TimeZoneSelectionMenu)"
ln -fs $tZone /etc/localtime
timedatectl set-ntp true
timedatectl status
echo
echo $tZone