#! /bin/sh

# KMW 2016-02-07

AP="$(iwgetid -r)"
[ "$AP" ] || AP="not connected"

echo "AP: $AP"

flite -t "$AP"
