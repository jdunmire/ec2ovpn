# OpenVPN Community Edition on an AWS EC2 instance
This project sets up an OpenVPN server on an EC2 instance that can be
used to reduce the risk of using open and public WiFi access points.
[Recommendations][1] [for using a VPN][2] are common and wide spread
simply search for `how to safely use public wifi`. 

This project sets up a VPN on an Amazon EC2 compute instance. The VPN is
community edition of [OpenVPN][ovpn]. It will be deployed on
[Ubuntu][ubuntu]
because I am familiar with Ubuntu, there are packaged versions of
OpenVPN in the distro repository, and there is a Amazon Machine Image
(AMI) for Ubuntu that is elible for the [AWS Free Usage Tier][awsfree].

##### Table of Contents  
* [Preparation](#preparation)  
   * [AWS Account](#aws)
   * [Certificates](#certs)
     * [Setup](#setupCA)
     * [Server Certificate](#serverCert)
     * [Client Certificate](#clientCert)
   * [DDNS Hostname](#DDNSHost)
   * [SSH Key](#sshkey)
* [Launch EC2 Instance](#launchec2)
* [Configure Server](#setupServer)
* [Configure Client](#setupClient)
  * [Ubuntu](#ubuntuClient)
  * [Android](#androidClient)
* [Stop/Start EC2 Instance](#startStop)

<a name="preparation"></a>
## Preparation
<a name="aws"></a>
### AWS Account
AWS account setup is not covered here, but is well documented at the
[AWS web site](https://aws.amazon.com/). These links are good starting points:

  * [AWS Free Usage Tier](http://aws.amazon.com/free)
  * [Getting Started](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html)

<a name="certs"></a>
### Credentials
[Easy-RSA][easyrsa] is used to create and sign the credentials. Easy-RSA
is included in the openvpn package on Ubuntu 12.04. On Ubuntu 14.04 it
is a separate package. Some guides (the [Ubuntu Guide][ubuntu_openvpn]
for example) use Easy-RSA from those packages and create the credentials
on the server itself. This project will create the credentials on your
local host both to minimize the work on the server and to keep
unnecessary sensitive files off the server.

<a name="setupCA"></a>
#### Setup
Download a release tarball from
https://github.com/OpenVPN/easy-rsa/releases. These instructions are
for
[v2.2.2](https://github.com/OpenVPN/easy-rsa/releases/tag/2.2.2)
    
    $ wget https://github.com/OpenVPN/easy-rsa/releases/download/2.2.2/EasyRSA-2.2.2.tgz
    $ tar -xzf EasyRSA-2.2.2.tgz
    $ cd EasyRSA-2.2.2/

Edit the `vars` file and adjust the following to your environment. If
its not clear to you what the value _should_ be, you can use an
arbitrary string (such as `MyVPN`). The values aren't that important
unless you are going to be signing things for others.

    export KEY_COUNTRY="US"
    export KEY_PROVINCE="NC"
    export KEY_CITY="Winston-Salem"
    export KEY_ORG="Example Company"
    export KEY_EMAIL="steve@example.com"
    export KEY_OU="MyVPN"
    export KEY_NAME="MyVPN"
    export KEY_CN="MyVPN"

Now generate the master Certificate Authority (CA). The values you
adjusted in the `vars` file will be the default answers to the questions
asked by `./build-ca`.

    $ source ./vars
    $ ./clean-all
    $ ./build-ca

The resulting CA file is `keys/ca.crt`.

<a name="serverCert"></a>
#### Server
Next build the server certificate and the Diffie Hellman parameters
file. `myserver` will be used to construct the file names for the
server certificate and key, if you use a differnet value you will need
to modify the `server.conf` file.

Accept defaults for all the values, leaving the _challenge password_ and
_optional company name_ empty. You will have to answer `y` to the `Sign
the certificate?` and `1 out of 1 certificate requests certified,
commit?` questions.

    $ ./build-key-server myserver
    $ ./build-dh

The files your are going to use are: `keys/myserver.crt`,
`keys/myserver.key`, and `keys/dh2048.pem`.

<a name="clientCert"></a>
#### Client
You will need at least one client certificate, but it is a good idea to
use a different certificate for each of your computers and mobile
devices. There are several EasyRSA scripts to build the client
certificates. Creating a PKCS#12 archive simplifies installing the keys
and since it is an encrypted archive it can be safely moved over
insecure channels. 

`clientID` will used as part of the certificate file name. Accept the
default values, leave _challenge password_ and _optional company anem_
empty. Answer `y` to the `Sign the certificate?` and `1 out of 1
certificate requests certified, commit?` questions.

**DO NOT FORGET THE Export Password**

    $ cd EasyRSA-2.2.2/
    $ ./build-key-pkcs12 clientID

There is only one file you will need: `keys/clientID.p12` where
`clientID` is the argument you specified.

<a name="DDNSHost"></a>
### DDNS Hostname
This is somewhat optional. If you don't want to setup a dynamic DNS host
name, you can use an ElasticIP or even the public IP assigned when the
EC2 instance gets started. The down side of the ElasticIP is that it
costs you money when you EC2 instance is not running. The down side of
the EC2 public IP is that it changes every time the instance is stopped
and restarted. You will have to update the configuration files on the
instance and on your clients each time you stop and start the EC2
instance.

It is much easier to a use a dynamic DNS (DDNS) service. The scripts in this
project will automatically update the IP address at the DDNS when the VPN is
started. These scripts are specific to
[freeDNS][freedns], but should be easy to modify for other services.

Use the fully qualified host
name (circled in green) and the URL associated with the `DirectURL` link
(circled in red) from the this table on the [freeDNS][freedns]:[Dynamic
DNS page](http://freedns.afraid.org/dynamic/) to configure `dynamicSetup.sh` and `client.ovpn`.

![alt text](DynamicDNSUpdateURLs.png)


  * Edit `dynamicSetup.sh` and set `DDNS_URL`.

  * Edit `client.ovpn` and replace `SERVER_DNS_OR_IP` with the fully qualified host name of your server

<a name="sshkey"></a>
### SSH Key
You will need an SSH Key to login to the EC2 instance. The easiest thing
to do is to import the you local default key (`~/.ssh/id_rsa.pub`) into
your AWS account. If you don't have the `/.ssh/id_rsa.pub` file, then
follow the instructions in this [article at
GitHub](https://help.github.com/articles/generating-ssh-keys)

The instructions for importing your key are in the [AWS
Documentation](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws)


<a name="launchec2"></a>
## Launch EC2 Instance
You are finally ready to launch you EC2 instance. If you haven't done
this before, then it is worth your time work through the [AWS Getting
Started](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html)
example.

These are the key configuration details:

  * Select the `Ubuntu Server 14.04 LTS (PV), 64-bit` AMI
  * Select a Micro Instance (`t1.micro`)
  * Select the SSH key you imported [above](#sshkey)
  * Configure the security group with a Custom UDP Rule for the OpenVPN
    port:

![alt text](EditInboundRules.png)

The following are suggestions/guidelines that work well for me:

  * Don’t leave the Name tag empty, set a name that will make it clear to you what will be running on the instance.
  * Don’t reuse an existing security group. If you try to reuse security groups then you have to balance how the settings will effect each instance in the group.
  * Don’t accept the default Security Group name and description. Make it clear that the security group is associated with the instance you are creating.
  * The best security is to limit SSH access to only known IP addresses
    (see the image above).

__Note__: you can also log onto the instance via ssh through the VPN
(just use the server address on the VPN subnet, typically 10.8.0.1),  so there is seldom a good reason to open the SSH access beyond your known IP addresses.

  
<a name="#setupServer"></a>
## Configure Server
Log on to the EC2 instance. Use either the public IP or the AWS DNS name.

    local$ ssh ubunut@ec2XXXXXXXXXX.compute-1.amazonaws.com
    Enter passphrase for key xxxxxxxxxxxxxxxxx:
    Welcome to Ubuntu 14.04 LTS ...
    ...
    ubuntu@domU:~$ 

Install OpenVPN:

    ubuntu#domU:~$ sudo apt-get install openvpn

Copy and install the configuration files on the server. Restart OpenVPN
and clean up.

    local$ ./pkg_server_files.sh
    local$ scp server_files.tgz ubunut@ec2XXXXXXXXXX.compute-1.amazonaws.com:.
    local$ ssh ubunut@ec2XXXXXXXXXX.compute-1.amazonaws.com
    ubuntu@domU:~$ tar -xzf server_files.tgz
    ubuntu@domU:~$ cd server_files
    ubuntu@domU:~$ sudo ./setup_server.sh
    ubuntu@domU:~$ sudo service openvpn restart
    ubuntu@domU:~$ cd ..
    ubuntu@domU:~$ rm -rf server_files/ server_files.tgz


<a name="#setupClient"></a>
## Configure Client

<a name="#ubuntuClient"></a>
### Ubuntu

<a name="#androidClient"></a>
### Android

<a name="#startStop"></a>
## Stop/Start EC2 Instance]

------------------
[1]: http://arstechnica.com/security/2011/01/stay-safe-at-a-public-wi-fi-hotspot/ "arstechnica: How to stay safe at a public WiFi hotspot"
[2]: http://consumerist.com/2008/10/06/the-idiot-proof-way-to-securely-use-public-wi-fi/ "Consumerist: The Idiot-Proof Way to Securely Use Public WiFi"
[easyrsa]: https://github.com/OpenVPN/easy-rsa "Easy-RSA"
[ovpn]: http://openvpn.net/index.php/open-source.html
[ubuntu]: http://www.ubuntu.com/server
[awsfree]: http://aws.amazon.com/free/
[freedns]: http://freedns.afraid.org
