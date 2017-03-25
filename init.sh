#!/usr/bin/env bash -x

## configure env vars
source config.sh

######################################################
### Step 1: Configure user 'vpn' on target machine ###
######################################################


## Create a new vpn user on server and configure client SSH access
source ./user_setup.client.sh


####################################
### Step 2: Configure VPN server ###
####################################

## This step generates VPN credentials for a single client (presumably this machine)
## To generate credentials for other clients (e.g. mobile device, etc),
## repeat Steps 2 and 3 with a different CLIENT_NAME (in config.sh) for each device

## A: Configure VPN server
ssh -i $CLIENT_VPN_RSA_KEY -l $SERVER_VPN_USER $SERVER "SERVER=$SERVER CLIENT_NAME=$CLIENT_NAME bash -s " < './server1.sh'

## copy scripts to server
## (destination directories were created in server1.sh)
scp -i $CLIENT_VPN_RSA_KEY make_config.sh $SERVER_VPN_USER@$SERVER:~/client-configs

## B: Configure VPN server
ssh -i $CLIENT_VPN_RSA_KEY -l $SERVER_VPN_USER $SERVER "SERVER=$SERVER CLIENT_NAME=$CLIENT_NAME bash -s " < './server2.sh'

########################################
### Step 3: Configure client machine ###
########################################
CLIENT_CREDS_DIR=$HOME/.ovpn;

## create directory on client for certs/keys
mkdir -p $CLIENT_CREDS_DIR;

## Create client credentials for $CLIENT_NAME from server to local machine
scp -i $CLIENT_VPN_RSA_KEY $SERVER_VPN_USER@$SERVER:~/client-configs/files/${CLIENT_NAME}.ovpn $CLIENT_CREDS_DIR;

## copy certs/keys created on vpn server to client
scp -i $SSH_KEY $SERVER_LOGIN_USER@$SERVER:$SERVER_KEYS_DIR/${CLIENT_NAME}.key $CLIENT_CREDS_DIR;
scp -i $SSH_KEY $SERVER_LOGIN_USER@$SERVER:/etc/openvpn/ca.crt $CLIENT_CREDS_DIR;

## install config in tunnelblick
## note: requires tunnelblick to be installed first!
## see: https://tunnelblick.net/downloads.html
open $HOME/.ovpn/${CLIENT_NAME}.ovpn

