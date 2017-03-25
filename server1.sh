#!/usr/bin/env bash

# These commands were taken primarily from a Digital Ocean tutorial:
# https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04

# check if user has sudo access
if ! sudo ls /; then
   echo "This script must be run with sudo privileges. Specify a user with sudo privileges using the -u flag."
   set -x
   exit 1
fi

sudo rm -rf /etc/openvpn
sudo mkdir /etc/openvpn

###################################
### STEP 1: Install OpenVPN     ###
###################################

sudo apt-get --assume-yes update
sudo apt-get --assume-yes install openvpn easy-rsa


###################################
### STEP 2: Set Up CA Directory ###
###################################

## copy easy-rsa template dir into home dir using make-cadir
OPENVPN_CA_DIR="$HOME/openvpn-ca"
rm -rf "$OPENVPN_CA_DIR"; make-cadir "$OPENVPN_CA_DIR";

## vpn user owns this directory
sudo chown -R $USER:$USER $OPENVPN_CA_DIR;
sudo chmod 700 $OPENVPN_CA_DIR;


######################################
### STEP 3: Configure CA Variables ###
######################################

## assign vars file path
VARS_FILE="$OPENVPN_CA_DIR/vars"

## edit KEY_EMAIL
## (change the following line to your contact email)"
KEY_EMAIL="chris@christopherwalter.com"
sudo sed -i -e 's/export KEY_EMAIL=..*/export KEY_EMAIL="'$KEY_EMAIL'"/' $VARS_FILE

## set KEY_NAME
## !! do not change this unless you know what you're doing !!
KEY_NAME="server"
sudo sed -i -e 's/export KEY_NAME=..*/export KEY_NAME="'$KEY_NAME'"/' $VARS_FILE


###############################################
### STEP 4: Build the Certificate Authority ###
###############################################

## source VARS file that we just edited
cd $OPENVPN_CA_DIR && source $VARS_FILE;

## ensure we're operating in a clean environment
cd $OPENVPN_CA_DIR && ./clean-all;

## build CA root
## note: '--batch' prevents having to confirm config that we set in VARS
cd $OPENVPN_CA_DIR && ./build-ca --batch;


####################################################################
### STEP 5: Create Server Certificate, Key, and Encryption Files ###
####################################################################

# generate OpenVPN server certificate and key pair
cd $OPENVPN_CA_DIR && ./build-key-server --batch $KEY_NAME;


## generate Diffie-Hellman keys
## (to use during key exchange)
cd $OPENVPN_CA_DIR && ./build-dh;

OVPN_KEYS_DIR=$OPENVPN_CA_DIR/keys;

## generate HMAC signature
## (to strengthen server's TLS verification capabilities)
cd $OPENVPN_CA_DIR && openvpn --genkey --secret $OVPN_KEYS_DIR/ta.key;


########################################################
### STEP 6: Generate Client Certificate and Key Pair ###
########################################################

## note: this step generates a single client cert + key pair.
## Each device that uses the VPN needs its own client cert/key.
## You can re-run these commands with a unique CLIENT_NAME
## to create client cert/key pairs for more devices (e.g. a phone).


## set CLIENT_NAME for this cert/key pair
## (change this for each device, if creating key pairs for 2 or more devices)

## source VARS again
cd $OPENVPN_CA_DIR;
source $VARS_FILE;

## note: The next command produces credentials
## that are not password protected. If you wish to
## produce password-protected creds, comment out the
## command and uncomment the command below it.

./build-key --batch $CLIENT_NAME; ## for password-protected creds, comment out this line
# ./build-key-pass $CLIENT_NAME; ## for password-protected creds, uncomment this line


#########################################
### STEP 7: Configure OpenVPN Service ###
#########################################

## copy the files we created in Step 6 to /etc/openvpn
cd $OVPN_KEYS_DIR && sudo cp ./ca.crt ./ca.key ./server.crt ./server.key ./ta.key ./dh2048.pem /etc/openvpn;

## unzip a sample OpenVPN configuration file into
## configuration directory so that we can use
## it as a basis for our setup
gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | sudo tee /etc/openvpn/server.conf


## modify the server configuration file /etc/openvpn/server.conf
SERVER_CONF=/etc/openvpn/server.conf;

sudo chown $USER:$USER $SERVER_CONF;
sudo chmod 700 $SERVER_CONF;

## HMAC section

## uncomment line with 'tls-auth' directive
sudo sed -i -e '/tls-auth ta.key 0.*/s/^;//' $SERVER_CONF;
## append line for 'key-direction'
sudo sed -i -e '/tls-auth ta.key 0.*/a \
key-direction 0' $SERVER_CONF;


## cryptographic ciphers section

## uncomment line 'cipher AES-128-CBC'
sudo sed -i -e '/cipher AES-128-CBC.*/s/^;//' $SERVER_CONF;
## append line for 'auth SHA256'
sudo sed -i -e '/cipher AES-128-CBC.*/a \
auth SHA256' $SERVER_CONF;

## user + group settings section

## uncomment line 'user nobody'
sudo sed -i -e '/user nobody.*/s/^;//' $SERVER_CONF;
## uncomment line 'group nogroup'
sudo sed -i -e '/group nogroup.*/s/^;//' $SERVER_CONF;


## redirect-gateway section
## note: this is necessary to force all client web traffic through vpn

## uncomment line 'push "redirect-gateway def1 bypass-dhcp"'
sudo sed -i -e '/push "redirect-gateway def1 bypass-dhcp".*/s/^;//' $SERVER_CONF;

## dhcp-option section
## note: this is necessary to force all client web traffic through vpn

## uncomment line 'push "dhcp-option DNS 208.67.222.222"'
sudo sed -i -e '/push "dhcp-option DNS 208.67.222.222".*/s/^;//' $SERVER_CONF;

## uncomment line 'push "dhcp-option DNS 208.67.220.220"'
sudo sed -i -e '/push "dhcp-option DNS 208.67.220.220".*/s/^;//' $SERVER_CONF;


## !! OPTIONAL !!
## Uncomment the two lines below to change port config to TCP 443 from default UDP 1194.
## If you have no need to use a different port, leave the following commands commented out.

# sudo sed -i -e 's/port.*/port 443/' $SERVER_CONF;
# sudo sed -i -e 's/proto.*/proto tcp/' $SERVER_CONF;


###############################################
### STEP 8: Adjust Server Networking Config ###
###############################################

## modify the file /etc/sysctl.conf
SYSCTL_CONF=/etc/sysctl.conf;

## uncomment line 'net.ipv4.ip_forward=1'
sudo sed -i -e '/net.ipv4.ip_forward=1.*/s/^#//' $SYSCTL_CONF;

## read sysctl file and adjust values for current session
sudo sysctl -p;


## add vpn config to firewall

INTERFACE=$(ip route | grep '^default\s\+via\s\+[0-9\.]\+\s\+dev\s\+\(.\+\)\s*$' | tr -s ' ' | cut -d ' ' -f5);

if [[ -z "$INTERFACE" ]]; then
   echo "The default network interface could not be parsudo sed. Run 'ip route | grep default' to determine the default interface.";
   exit 1;
fi

UFW_OVPN_RULES='

# START OPENVPN RULES
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
# Allow traffic from OpenVPN client to '"$INTERFACE"'
-A POSTROUTING -s 10.8.0.0/8 -o '"$INTERFACE"' -j MASQUERADE
COMMIT
# END OPENVPN RULES
#
';

RULES_FILE=/etc/ufw/before.rules;

## add NAT rules
sudo grep -Fq 'START OPENVPN RULES' $RULES_FILE || (sudo echo -e "${UFW_OVPN_RULES}\n$(sudo cat $RULES_FILE)" | sudo tee -a "$RULES_FILE");

## allow packet forwarding
sudo sed -i -e 's/DEFAULT_FORWARD_POLICY=.*$/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw;

## open up udp 1194 for VPN
## note: if you changed the port/protocol config (e.g. to tcp 443), change this line to match that
sudo ufw allow 1194/udp;
sudo ufw allow 22/tcp

## reload ufw
sudo ufw reload;

################################################
### STEP 9: Start and Enable OpenVPN Service ###
################################################

## start OpenVPN service
sudo systemctl start openvpn@server;

## enable service to start automatically at boot
sudo systemctl enable openvpn@server;

#######################

############################################################
### STEP 10a: Create Client Configuration Infrastructure ###
############################################################

SAMPLE_CONFIG_DIR=/usr/share/doc/openvpn/examples/sample-config-files;
CLIENT_CONFIG_DIR=$HOME/client-configs;
BASE_CONFIG=$CLIENT_CONFIG_DIR/base.conf;

## create dir structure to store the files
mkdir -p $CLIENT_CONFIG_DIR/files;

## make sure our user has access
sudo chown -R $USER:$USER $CLIENT_CONFIG_DIR;

## restrict permissions since client keys will be embedded in config files
sudo chmod -R 700 $CLIENT_CONFIG_DIR;

## copy example client config to use as base config
cp $SAMPLE_CONFIG_DIR/client.conf $BASE_CONFIG;

## modify example config with our values

## change 'remote [IP] [PORT]' to vpn server IP and port
sudo sed -i -e 's/^remote\s\s*..*\s\s*[0-9]*$/remote '"$SERVER $PORT"'/' $BASE_CONFIG

## change proto to vpn proto
PROTO='udp'
sudo sed -i -e 's/^proto\s\s*[a-z][a-z]*$/proto '"$PROTO"'/' $BASE_CONFIG;

## uncomment line 'user nobody'
sudo sed -i -e '/user nobody.*/s/^;//' $BASE_CONFIG;
## uncomment line 'group nogroup'
sudo sed -i -e '/group nogroup.*/s/^;//' $BASE_CONFIG;


## comment out 'ca', 'cert', 'key' directives
## we will be adding the certs and keys within the file itself
sudo sed -i -e '/^ca\s\s*.*[a-z][a-z]*\.crt$/s/^/#/' $BASE_CONFIG;
sudo sed -i -e '/^cert\s\s*.*[a-z][a-z]*\.crt$/s/^/#/' $BASE_CONFIG;
sudo sed -i -e '/^key\s\s*.*[a-z][a-z]*\.key/s/^/#/' $BASE_CONFIG;

#ca ca.crt
#cert client.crt
#key client.key

## cipher and auth directives should match /etc/openvpn/server.conf
sudo sed -i -e 's/^;\?cipher.*$/cipher AES-128-CBC/' $BASE_CONFIG
## append line for 'auth SHA256'
sudo sed -i -e '/^cipher AES-128-CBC.*/a \
auth SHA256\
key-direction 1\
   ' $BASE_CONFIG;


## append commented out lines for linux clients
## these are only enabled for a linux client with /etc/openvpn/update-resolv-conf file

## If your client is running Linux and has an /etc/openvpn/update-resolv-conf
## file, you should uncomment the three lines within the string that is echoed below
echo '
# script-security 2
# up /etc/openvpn/update-resolv-conf
# down /etc/openvpn/update-resolv-conf' >> $BASE_CONFIG;


