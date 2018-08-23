#!/bin/bash

sudo apt-get install at dnsutils -y

if [ $# -lt 5 ]; then
    echo "Execution format ./install.sh STAKEADDR EMAIL FQDN REGION NODETYPE"
    exit
fi

echo "$1 $2 $3 $4 $5"

# at now + 2 minutes -f /tmp/init.sh $1 $2 $3 $4 $5

sleep 60
/tmp/init.sh $1 $2 $3 $4 $5
