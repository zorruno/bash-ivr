#! /bin/sh

# KMW 2016-02-07

#gpspipe -w -n5 | grep -m1 TPV | jq '.lat,.lon | tostring | .[0:8]' | while read L; do 
#   flite -t "$L"
#done

GPS=$(gpspipe -w -n5 | grep -m1 TPV | jq . | sed -rn "/(mode|lat|lon)/ {s/lat/latitude/; s/lon/longitude/; p}")
echo "GPS: $GPS"
echo "$GPS" | flite

