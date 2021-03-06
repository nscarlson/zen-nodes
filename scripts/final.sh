#!/bin/bash

# Installation variables
STAKEADDR=${1}
EMAIL=${2}
FQDN=${3}
REGION=${4}
NODETYPE=${5}
IPV4=$(dig $FQDN A +short)

echo "chown blocks and chainstate folders recursively to the ${USER}"
sudo chown -R $USER ~/.zen/{blocks,chainstate}

echo "Verify correct FQDN is set"
echo $FQDN
sed -e 1b -e '$!d' $HOME/.bashrc

echo "Install a certificate certbot will be used to generate and validate your certificate"
sudo certbot certonly -n --agree-tos --register-unsafely-without-email --standalone -d $FQDN > /dev/null

echo "Copy the root CA as required for Ubuntu"
sudo cp /etc/letsencrypt/live/$FQDN/chain.pem /usr/local/share/ca-certificates/chain.crt > /dev/null

echo "Update the certificate store with the root CA copied"
sudo update-ca-certificates

echo "Allow the non-root user for zend access to the cert and private key"
sudo chown -R root:sudo /etc/letsencrypt/
sudo chmod -R 750 /etc/letsencrypt/

echo "Stop and start zend to pick up the new configuration, certificate and private key"
zen-cli stop && sleep 30 && zend && sleep 30

##########################################################

echo "Generate a new t_address"
zen-cli getnewaddress > /dev/null && zen-cli listaddresses | jq -r '.[1]'
t_address=`zen-cli listaddresses | jq -r '.[1]'`

# Prompt admin to send 0.05 ZEN to newly-generated t_address
echo "***********************************"
echo "ADMIN: Send 0.05 ZEN to ${t_address}"

echo "ADMIN: Set up z_addresses"
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
mkdir config && cd config

echo "Create the config file for nodetracker"
cat << EOF > config.json
{
 "active": "${NODETYPE}",
 "${NODETYPE}": {
  "nodetype": "${NODETYPE}",
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

cat config.json

# Install the node tracker with npm
npm install > /dev/null

##########################################################

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
sudo chown -R $USER:$USER $HOME/

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
