#! /bin/sh

# KMW 2016-02-01

grep -i "^nameserver" /etc/resolv.conf | while read DUMMY IP; do 
   IP_SPEECH=$(echo "$IP" | sed "s/./& /g; s/\./dot/g")
   echo "nameserver: $IP_SPEECH"
   flite -t "name server $IP_SPEECH"
   sleep 0.1
done
