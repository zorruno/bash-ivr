#! /bin/sh

# KMW 2016-02-07

IW=$(iwconfig wlan0 | sed -n "/Link Quality/ {p}")
echo "IW: $IW"

flite -t "$IW"
