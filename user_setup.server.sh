#!/usr/bin/env bash

## log command output
set -x

## remember login user
SERVER_LOGIN_USER=$USER

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# get cmd line vars (passed from client script):
while getopts ":l:m:" opt; do
  case $opt in
    l) SERVER_VPN_USER="$OPTARG"
    ;;
    m) SERVER_VPN_PUB_KEY="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

## make sure we have sudo access on target machine
timeout 2 sudo id && echo "Confirmed sudo privileges for user '$SERVER_LOGIN_USER'" || echo "$SERVER_LOGIN_USER does not have sudo privileges. Please provide an ssh user with sudo access on target machine.";

#####################################
### STEP 2: Create a new vpn user ###
#####################################

if id ${SERVER_VPN_USER} >/dev/null 2>&1; then
  echo "User '$SERVER_VPN_USER' exists. Deleting user '$SERVER_VPN_USER' and recreating."

  ## delete vpn user
  sudo userdel -fr $SERVER_VPN_USER;

else
    echo "User '$SERVER_VPN_USER' does not exist on target machine."
fi

echo "Creating new user '$SERVER_VPN_USER'..."
## create user
sudo adduser --disabled-password --gecos "" $SERVER_VPN_USER;

echo "...granting sudo privileges to user '$SERVER_VPN_USER'..."

#################################################
### Step 3: Grant root privileges to vpn user ###
#################################################

## grant sudo privileges to vpn user
sudo usermod -aG sudo $SERVER_VPN_USER;

## remove password for vpn user sudo commands
sudo bash -c -- 'echo "'"$SERVER_VPN_USER"'    ALL=(ALL) NOPASSWD:ALL" | (EDITOR="tee -a" visudo)';

#######################################################
### Step 4: Add pub key authentication for vpn user ###
#######################################################

SERVER_VPN_HOME=/home/$SERVER_VPN_USER;

## create ~/.ssh for vpn user (will contain rsa public key from client)
sudo mkdir $SERVER_VPN_HOME/.ssh;

## create $VPN_HOME/.ssh/authorized_keys
SERVER_VPN_AUTHORIZED_KEYS_FILE="$SERVER_VPN_HOME/.ssh/authorized_keys";
sudo touch "$SERVER_VPN_AUTHORIZED_KEYS_FILE"

## add client public key to authorized keys
sudo echo $SERVER_VPN_PUB_KEY >> $SERVER_VPN_AUTHORIZED_KEYS_FILE;

## grant ownership of $VPN_HOME/.ssh to vpn user
sudo chown -R vpn:vpn $SERVER_VPN_HOME/.ssh;

## restrict permissions for $VPN_HOME/.ssh
sudo chmod 700 $SERVER_VPN_HOME/.ssh;

## restrict permissions for authorized_keys
sudo chmod 600 $SERVER_VPN_AUTHORIZED_KEYS_FILE;


#############################################
### Step 5: Disable ssh password (IGNORE) ###
#############################################

## nothing to do here

###################################
### Step 6: Test login (IGNORE) ###
###################################

## nothing to do here


##############################
### Step 7: Setup Firewall ###
##############################

## allow SSH connections
sudo ufw allow 22/tcp

## enable firewall
echo "yes" | sudo ufw enable;

