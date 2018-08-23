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

IPV4=$(dig $fqdn A +short)

echo "Add FQDN to HOSTS file"
echo $(hostname -I | cut -d\  -f1) $(hostname) | sudo tee -a /etc/hosts

echo "Update package cache"
sudo apt-get update -y > /dev/null

echo "Install the initial packages"
sudo apt-get install build-essential software-properties-common apt-transport-https lsb-release dirmngr pwgen git jq ufw curl sshpass -y > /dev/null

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

mkdir $HOME/.zen

echo "Create the config file for zend"
cat << EOF $HOME/.zen/zen.conf
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

######################################################

echo "chown blocks and chainstate folders recursively to the ${USER}"
sudo chown -R $USER ~/.zen/{blocks,chainstate}

echo "Start the zen daemon with rescanning"
zend --rescan && sleep 30

echo "Create basic firewall rules"
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow ssh/tcp
sudo ufw limit ssh/tcp
sudo ufw allow http/tcp
sudo ufw allow https/tcp
sudo ufw allow 9033/tcp
sudo ufw logging on
sudo ufw -f enable
sudo ufw status

echo "Enable UFW with systemctl"
sudo systemctl enable ufw

# echo "Wait for the DNS TTL"
# sleep 60

echo "Install a certificate certbot will be used to generate and validate your certificate"
sudo certbot certonly -n --agree-tos --register-unsafely-without-email --standalone -d $FQDN > /dev/null

echo "Copy the root CA as required for Ubuntu"
sudo cp /etc/letsencrypt/live/$FQDN/chain.pem /usr/local/share/ca-certificates/chain.crt > /dev/null

echo "Update the certificate store with the root CA copied"
sudo update-ca-certificates

# Add the certificate and key locations to zen.conf
echo "tlscertpath=/etc/letsencrypt/live/$FQDN/cert.pem" >> $HOME/.zen/zen.conf
echo "tlskeypath=/etc/letsencrypt/live/$FQDN/privkey.pem" >> $HOME/.zen/zen.conf

echo "Allow the non-root user for zend access to the cert and private key"
sudo chown -R root:sudo /etc/letsencrypt/
sudo chmod -R 750 /etc/letsencrypt/

echo "Stop and start zend to pick up the new config, cert, and private key"
zend && sleep 30

# Output network info
zen-cli getnetworkinfo

##########################################################

echo "Generate one new t_address"
zen-cli getnewaddress > /dev/null && zen-cli listaddresses | jq -r '.[1]'

t_address=`zen-cli listaddresses | jq -r '.[1]'`

# Prompt admin to send 0.05 ZEN to newly-generated t_address
echo "***********************************"
echo "ADMIN: Send 0.05 ZEN to ${t_address}"

echo "ADMIN: Set up z_ addresses"
# Wait for node to acknowledge confirmed balance at newly-generated t_address
# until sendToZAddresses | grep -m 1 "\"transparent\": \"0.0499\"" do sleep 10; done

# Generate two z_addresses and split balance between them
# zen-cli z_sendmany $(zen-cli listaddresses | jq -r '.[1]') '[{"address": "'$(zen-cli z_getnewaddress)'", "amount": 0.0249},{"address": "'$(zen-cli z_getnewaddress)'", "amount": 0.0249}]'

##########################################################

echo "Install NPM and upgrade to latest version"
sudo apt-get install npm -y && sudo npm install -g n && sudo n latest > /dev/null

echo "Change directory (cd) to the user's home directory and clone the Node Tracker software"
cd $HOME && git clone https://github.com/ZencashOfficial/nodetracker.git > /dev/null

echo "Change directory (cd) to where the software has been cloned"
cd nodetracker

echo "Create nodetracker config directory"
mkdir config

cat << EOF > $HOME/nodetracker/config/config.json
{
 "active": "secure",
 "secure": {
  "nodetype": "secure",
  "nodeid": null,
  "servers": [
   "ts2.eu",
   "ts1.eu",
   "ts3.eu",
   "ts4.eu",
   "ts4.na",
   "ts3.na",
   "ts2.na",
   "ts1.na"
  ],
  "stakeaddr": "${STAKEADDR}",
  "email": "${EMAIL}",
  "fqdn": "${FQDN}",
  "ipv": "4",
  "region": "${REGION}",
  "home": "ts1.${REGION}",
  "category": "none"
 }
}
EOF

echo "Install the node tracker npm dependencies"
npm install > /dev/null

echo "Create systemd unit file for zend"
echo \
"[Unit]
Description=Zen daemon
 
[Service]
User=$USER
Type=forking
ExecStart=/usr/bin/zend -daemon -pid=$HOME/.zen/zend.pid
PIDFile=$HOME/.zen/zend.pid
Restart=always
RestartSec=10
 
[Install]
WantedBy=multi-user.target" | sudo tee /lib/systemd/system/zend.service

echo "Create systemd unit file for nodetracker"
echo \
"[Unit]
Description=Zen node daemon installed on ~/nodetracker/
 
[Service]
User=$USER
Type=simple
WorkingDirectory=$HOME/nodetracker/
ExecStart=$(which node) $HOME/nodetracker/app.js
Restart=always
RestartSec=10
 
[Install]
WantedBy=multi-user.target" | sudo tee /lib/systemd/system/zentracker.service

echo "Stop zend and apply ownership to the non-root user of all files created earlier"
zen-cli stop && sleep 30 && sudo chown -R $USER:$USER $HOME/

echo "Start zend and nodetracker using the new systemd unit files"
sudo systemctl start zend zentracker

# echo "Check the status of zend and nodetracker"
# echo "TODO: uncomment"
# sudo systemctl status zend zentracker

echo "Enable zend and nodetracker unit files at boot"
sudo systemctl enable zend zentracker

echo "Create zenupdate unit file to run certbot renewal"
echo \
"[Unit]
Description=zenupdate.service
 
[Service]
Type=oneshot
ExecStart=/usr/bin/certbot -q renew --deploy-hook 'systemctl restart zend'
PrivateTmp=true" | sudo tee /lib/systemd/system/zenupdate.service

echo "Create a zenupdate.timer unit scheduled to run daily at 06:00 UTC"
echo \
"[Unit]
Description=Run zenupdate unit daily @ 06:00:00 (UTC)
 
[Timer]
OnCalendar=*-*-* 06:00:00
Unit=zenupdate.service
Persistent=true
 
[Install]
WantedBy=timers.target" | sudo tee /lib/systemd/system/zenupdate.timer

echo "Stop and disable the standard certbot.timer"
sudo systemctl stop certbot.timer
sudo systemctl disable certbot.timer

echo "Test the zenupdate.service to ensure it works correctly"
sudo systemctl start zenupdate.service

# echo "Check the service status ensuring no failures are listed"
# sudo systemctl status zenupdate.service

echo "Start and enable the zenupdate.timer"
sudo systemctl start zenupdate.timer
sudo systemctl enable zenupdate.timer

# echo "Check the timer status, see if it shows an active (waiting) state"
# sudo systemctl status zenupdate.timer

#echo "List timers installed, verify zenupdate.timer is shown"
#sudo systemctl list-timers
