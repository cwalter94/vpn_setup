#!/usr/bin/env bash -x

# get vars from cmd line:
# s=server, u=ssh_user, c=client, k=ssh_key
while getopts ":s:u:c:k:" opt; do
  case $opt in
    s) SERVER="$OPTARG"
    ;;
    u) SERVER_LOGIN_USER="$OPTARG"
    ;;
    c) CLIENT_NAME="$OPTARG"
    ;;
    k) SSH_KEY="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

if [ -z $SERVER ]; then
    echo 'Must provide public server IP address.'
    exit 1
fi

if [ -z ${SSH_KEY} ]; then
    echo 'Must provide path to keyfile for SSH access to server.'
    exit 1
fi

if [ -z $CLIENT_NAME ]; then
    CLIENT_NAME='client1'
    echo "No vpn client name set. Defaulting to $CLIENT_NAME."
fi

if [ -z $SERVER_LOGIN_USER ]; then
    SERVER_LOGIN_USER='root'
    echo "No ssh user set. Defaulting to '$SERVER_LOGIN_USER'."
fi


## Variables relating to the client machine (running init.sh)
CLIENT_CERT_DIR="$HOME/.ovpn"
CLIENT_VPN_RSA_KEY="$HOME/.ssh/vpn_id_rsa"


## Variables relating to the target vpn server
SERVER_KEYS_DIR=$OPENVPN_CA_DIR/keys;
SERVER_VPN_USER='vpn'


