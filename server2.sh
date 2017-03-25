#!/usr/bin/env bash

# These commands were taken primarily from a Digital Ocean tutorial:
# https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04

# if ! id -u vpn; then
#    echo "User 'vpn' doesn't exist. Creating..."
#    adduser --disabled-password --gecos vpn
#    mkdir -p /home/vpn/.ssh/
#    cp $HOME/.ssh/authorized_keys /home/vpn/.ssh/
# fi

# check if user has sudo access
if ! sudo ls /; then
   echo "This script must be run with sudo privileges. Specify a user with sudo privileges using the -u flag."
   set -x
   exit 1
fi

############################################
### Step 10b (continued from server1.sh) ###
############################################

## we copied a convenience script to the server
## before running server2.sh

## make ~/client-configs/make_config.sh executable
chmod 700 ~/client-configs/make_config.sh;


###############################################
### Step 11: Generate Client Configurations ###
###############################################


cd ~/client-configs;
./make_config.sh $CLIENT_NAME;

exit 0;

