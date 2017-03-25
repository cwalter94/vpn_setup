#!/bin/bash

## RUN ONLY AFTER INIT_SERVER RUNS ON SERVER

while getopts ":s:u:c:k:" opt; do
  case $opt in
    s) SERVER="$OPTARG"
    ;;
    u) SSH_USER="$OPTARG"
    ;;
    c) CLIENT="$OPTARG"
    ;;
    k) SSH_KEY="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

if [ -z "$SERVER" ]; then
    echo 'Must provide server IP or public DNS.'
    exit 1
fi

if [ -z "${SSH_KEY}" ]; then
    echo 'Must provide path to keyfile for SSH access to server.'
    exit 1
fi

if [ -z "$CLIENT" ]; then
    echo "No client set. Assuming client1."
    CLIENT='client1'
fi

if [ -z "$SSH_USER" ]; then
    echo "No user set. Assuming user 'vpn'."
    SSH_USER='vpn'
fi

OVPN_DIRECTORY="$HOME/.ovpn"

if [ ! -d "$OVPN_DIRECTORY" ]; then
  echo "$OVPN_DIRECTORY" does not exist. Creating "$OVPN_DIRECTORY" ...
  echo mkdir $OVPN_DIRECTORY
  mkdir $OVPN_DIRECTORY
fi

scp -i $SSH_KEY $SSH_USER@$SERVER:/etc/openvpn/easy-rsa/keys/$CLIENT.crt ~/.ovpn

scp -i $SSH_KEY $SSH_USER@$SERVER:/etc/openvpn/easy-rsa/keys/$CLIENT.key ~/.ovpn

scp -i $SSH_KEY $SSH_USER@$SERVER:/etc/openvpn/easy-rsa/keys/client.ovpn ~/.ovpn

scp -i $SSH_KEY $SSH_USER@$SERVER:/etc/openvpn/ca.crt ~/.ovpn
