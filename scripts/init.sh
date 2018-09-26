#!/bin/bash

if [ $# -lt 5 ]; then
    echo "Execution format ./install.sh STAKEADDR EMAIL FQDN REGION NODETYPE"
    exit
fi

# Installation variables
STAKEADDR=${1}
EMAIL=${2}
FQDN=${3}
REGION=${4}
NODETYPE=${5}


echo "Add FQDN to HOSTS file"
echo $(hostname -I | cut -d\  -f1) $(hostname) | sudo tee -a /etc/hosts

echo "Update package cache"
sudo apt-get update -y > /dev/null

echo "Install the initial packages"
sudo apt-get install dnsutils build-essential software-properties-common apt-transport-https lsb-release dirmngr pwgen git jq ufw curl sshpass -y > /dev/null

IPV4=$(dig $FQDN A +short)

echo "Add the Horizen repository to the sources.list file"
echo 'deb https://zencashofficial.github.io/repo/ '$(lsb_release -cs)' main' | sudo tee --append /etc/apt/sources.list.d/zen.list > /dev/null

echo "Pull the gpg key used to sign Horizen packages"
gpg --keyserver ha.pool.sks-keyservers.net --recv 219F55740BBF7A1CE368BA45FB7053CE4991B669 > /dev/null

echo "Pull the gpg key from redundant key server"
gpg --keyserver keyserver.ubuntu.com  --recv 219F55740BBF7A1CE368BA45FB7053CE4991B669 > /dev/null

echo "Export the gpg key and add to apt, this enables package verification"
gpg --export 219F55740BBF7A1CE368BA45FB7053CE4991B669 | sudo apt-key add - > /dev/null

echo "Add the repository for certbot"
sudo add-apt-repository ppa:certbot/certbot -y > /dev/null

echo "Update the package cache again with the Horizen and certbot repositories added as sources"
sudo apt-get update -y > /dev/null

echo "Install the zend daemon and certbot"
sudo apt-get install zen certbot -y > /dev/null

echo "Download the required parameters for zend"
zen-fetch-params

echo "Create the .zen home directory"
mkdir $HOME/.zen

echo "Create the config file for zend"
cat << EOF > $HOME/.zen/zen.conf
rpcuser=$(pwgen -s 32 1)
rpcpassword=$(pwgen -s 64 1)
rpcport=18231
rpcallowip=127.0.0.1
rpcworkqueue=512
server=1
daemon=1
listen=1
txindex=1
logtimestamps=1
tlscertpath=/etc/letsencrypt/live/${FQDN}/cert.pem
tlskeypath=/etc/letsencrypt/live/${FQDN}/privkey.pem
externalip=${IPV4}
port=9033
EOF

cat $HOME/.zen/zen.conf

# Append external IPV4 into zen.conf
echo "externalip=$IPV4" >> $HOME/.zen/zen.conf

# Append port into zen.conf
echo "port=9033" >> $HOME/.zen/zen.conf

##########################################################

# Turn off and remove the swap file if one already exists

echo "Setting up /swapfile"
sudo swapoff /swapfile
sudo rm -f /swapfile

# Allocate the swapfile, changing the command as necessary
sudo fallocate -l 2G /swapfile

# Set permissions on the swapfile	
sudo chmod 600 /swapfile

# Format the file as swap space
sudo mkswap /swapfile

# Activate swap
sudo swapon /swapfile

echo "Edit the /etc/sysctl.conf file to specify the 'swappiness' behaviour"
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

echo "Edit the /etc/fstab file, specifying that swap should be mounted at boot"
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab

echo "Activate the updated configuration (without rebooting)"
sudo sysctl -p

echo "Remove blockchain data directories before bootstrapping"
# zen-cli stop
# rm -rf $HOME/.zen/{blocks,chainstate}
