#!/usr/bin/env bash

## log command output
set -x

##############################################################
### STEP 1: Configure client SSH creds for server vpn user ###
##############################################################

## Create ~/.ssh if doesn't exist
mkdir -p $HOME/.ssh;

## Create password-less ssh key pair for new vpn user
## Note: if these already exist, a prompt appears before they're overwritten
ssh-keygen -t rsa -N "" -f $CLIENT_VPN_RSA_KEY;

## plaintext pub key to pass to server script
SERVER_VPN_PUB_KEY=`cat $CLIENT_VPN_RSA_KEY.pub`;

## Create new vpn user on server
ssh -i ${SSH_KEY} -l $SERVER_LOGIN_USER $SERVER "sudo bash -s " -- < ./user_setup.server.sh -l "'${SERVER_VPN_USER}'" -m "'${SERVER_VPN_PUB_KEY}'";





