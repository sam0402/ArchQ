#!/bin/sh
sleep 10
while read line; do
    names+=$line' '
done <<< $(pactl list sinks | grep -E "Name:" | cut -d- -f3-4)

while read line; do
    desc+=${line//[[:blank:]]/}' '
done <<< $(pactl list sinks | grep -E "Description:" | cut -d: -f2)

a_name=($names)
a_desc=($desc)

[ -f ~/.default_sink ] || touch ~/.default_sink
for ((i=0; i < ${#a_name[@]}; i++))
do
    [ ${a_desc[$i]} == $(cat ~/.sink_def) ] && pactl set-default-sink raop-sink-${a_name[$i]}
done
exit 0
