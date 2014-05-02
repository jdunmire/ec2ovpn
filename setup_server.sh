#!/bin/bash
#
# setup_server.sh - configure openvpn server
#

OPENVPN_ETC="./etc/"
SERVER_CERT="myserver"

FILES="dh2048.pem ${SERVER_CERT}.crt server.conf setup_server.sh \
       dynamicSetup.sh ${SERVER_CERT}.key ca.crt"

# make sure this is being run with root privileges
if [ $(id -u) -ne 0 ]
then
    echo "ERROR: this script must be run as root."
    exit 1
fi

# make sure all files are present
for f in ${FILES}
do
    if [ ! -e $f ]
    then
        echo "ERROR: missing $f. Exiting."
        exit 1
    fi
done

# make sure the target directory exists
if [ ! -d ${OPENVPN_ETC} ]
then
    echo "ERROR: ${OPENVPN_ETC} does not exist."
    echo "       Check the openvpn installation."
    exit 1
fi

# copy file files
cp ${FILES} ${OPENVPN_ETC}

# set the file ownership to root
cd ${OPENVPN_ETC}
chown root:root ${FILES}

# set file permissions
chmod 644 ${FILES}
chmod 755 dynamicSetup.sh
chmod 600 ${SERVER_CERT}.key


