#! /bin/sh

# KMW 2016-02-01

IP=$(ifconfig wlan0 | sed -n "/inet addr/ {s/[^:]*://; s/ .*//; p}")
IP_SPEECH=$(echo "$IP" | sed "s/./& /g; s/\./dot/g")
echo "IP: $IP_SPEECH"

flite -t "I P $IP_SPEECH"
