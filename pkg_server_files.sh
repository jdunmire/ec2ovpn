#!/bin/bash
#
# pkg_server_files.sh - create tarball of files to be transferred to server
#

EASYRSA_KEYDIR="./EasyRSA-2.2.2/keys/"
KEY_FILES="ca.crt dh2048.pem myserver.crt myserver.key"
CONFIG_FILES="server.conf dynamicSetup.sh setup_server.sh"

# check to make sure the files have been configured
grep -v '#' dynamicSetup.sh | grep -q 'DDNS_URL='
if [ $? -ne 0 ]
then
    echo "WARNING: DDNS_URL has not been defined in dynamicSetup.sh."
    echo "         No dynamic DNS updates will be possible."
fi

if  grep -q SERVER_DNS_OR_IP client.ovpn 
then
    echo "WARNING: Configuration not complete. Server not specified in"
    echo "         client.ovpn."
fi

PKG_DIR=${PWD}/server_files
mkdir ${PKG_DIR}

cp ${CONFIG_FILES} ${PKG_DIR}
cd ${EASYRSA_KEYDIR}
cp ${KEY_FILES} ${PKG_DIR}
cd ${PKG_DIR}/..
tar -czf $(basename ${PKG_DIR}).tgz ./$(basename ${PKG_DIR})

rm -rf ${PKG_DIR}

echo "Created $(basename ${PKG_DIR}).tgz"
