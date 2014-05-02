#!/bin/sh
#
# dynamicSetup.sh - setup IP forwarding, NAT, and report IP to DDNS
#
# This script will be run each time the VPN is started. It will enable
# IP forwarding and optionally (if TOKEN is defined) update DDNS.
#

# Define DDNS_URL to enable dynamic DNS updates
#
# The following is specific to FreeDNS (http://freedns.afraid.org).
#
# Get the update URLfor your DNS entry at https://freedns.afraid.org/dynamic/
# it will look like this:
#
#    https://freedns.afraid.org/dynamic/update.php?VDJAMNOTREALMA==
#
#DDNS_URL="http://freedns.afraid.org/dynamic/update.php?VDJAMNOTREALMA=="

# File to flag that the dynamic DNS service has updated.
# Since the IP address for an EC2 instance changes only when the
# instance is stopped and restarted, the simple presence of a file
# record that the IP address has been reported.
IP_RECORD=/tmp/hostIP

# Enable IP forwarding and NAT
/sbin/iptables --flush
/sbin/iptables --table nat --flush
/sbin/iptables --delete-chain
/sbin/iptables --table nat --delete-chain
/sbin/iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
/sbin/sysctl -w net.ipv4.ip_forward=1

# Update DDNS if token is defined and if not previously reported.
if [ "x${DDNS_URL}" = "x" ]
then
    echo "WARNING: DDNS update URL not defined. Public IP will not be"
    echo "reported to the dynamic DNS server."
    exit
fi

if [ ! -e ${IP_RECORD} ]
then
	curl -k ${DDNS_URL}

        # it doesn't mater what we write to the IP_RECORD, but it may as
        # well be the Public IP:
	wget -qO${IP_RECORD} http://instance-data/latest/meta-data/public-ipv4

	echo "Public IP registered at a dynamic DNS service."

else

	echo "IP previously registered."
fi

