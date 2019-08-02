# flashRDBOX.sh - RDBOX command tool to write SD image files to SD card
This command performs two processes of creating the configuration file of RDBOX and writing the SD image file to the SD card using [hypriot/flash](https://github.com/hypriot/flash).  

## Getting Started(Docker)
Use the key file created by HQ construction.
* [By AWS](https://github.com/rdbox-intec/rdbox/wiki/setup-rdbox-hq-aws-4-ec2_import_key_pair-en)  
* [By VirtualBox](https://github.com/rdbox-intec/rdbox/wiki/setup-rdbox-hq-vb-2-prepare_virtual_machine-en)
```bash
# 1. Prepare key file.
$ cp -rf ${YOUR_ID_RSA} id_rsa
$ cp -rf ${YOUR_ID_RSA_PUB} id_rsa.pub

# 2. Download the latest RDBOX SD image.(https://github.com/rdbox-intec/rdbox/releases/latest)
$ wget https://github.com/rdbox-intec/rdbox/releases/download/v0.1.2/hypriotos-rpi-v1.10.0.rdbox-v0.0.26.img.zip -O rdbox.img

# 3. Docker run
$ sudo docker run --entrypoint /opt/flashRDBOX/bin/flashRDBOX.sh -v `pwd`:/flashRDBOX:ro --privileged -it rdbox/flash-rdbox:latest -p /flashRDBOX/id_rsa.pub -k /flashRDBOX/id_rsa /flashRDBOX/rdbox.img
  :
  :
  (Interactive Mode)
  :
  :
done.xle
```

**IN Interactive Mode**  
Specify with the -n option or specify interactively.
For interactive mode, select the host type from the following and specify suffix string.
```bash
host type:
0. other
1. master
2. slave
3. vpnbridge
What number do you select? [0-3]
```
```bash
suffix? 
```
If `0. other` is selected, any host name can be specified. This is the same as the -n option.
For example, if you select `1. master` as host type and `00` as suffix, the host name becomes `rdbox-master-00`.

[For more infomation.(Docker)](#2-run-flashrdbox-from-docker-container)

[For more infomation.(Manual)](#Prepare)

[For more infomation.(Continuous writing)](#step---direct-mode)

# Contents
* [Prepare](#Prepare)
   - [OverView](#OverView)
   - [1) Prepare a Linux PC (Ubuntu/Debian) that has flash installed and can use an SD card adapter to write to the SD card](#1-prepare-a-linux-pc-ubuntudebian-that-has-flash-installed-and-can-use-an-sd-card-adapter-to-write-to-the-sd-card)
   - [2) Install the following tools to work together](#2-install-the-following-tools-to-work-together)
   - [3) git clone flashRDBOX](#3-git-clone-flashrdbox)
   - [4) Prepare the ssh key pair files (public key / private key) for the account specified by USER_NAME](#4-prepare-the-ssh-key-pair-files-public-key--private-key-for-the-account-specified-by-user_name)
   - [5) Determine the hostname](#5-determine-the-hostname)
* [Step - Interactive mode (default)](#step---interactive-mode-default)
   - [1) Copy the template file (user-data.params) of parameters for RDBOX SD image file](#1-copy-the-template-file-user-dataparams-of-parameters-for-rdbox-sd-image-file)
   - [2) Execute flashRDBOX.sh and write the SD image file to the SD card](#2-execute-flashrdboxsh-and-write-the-sd-image-file-to-the-sd-card)
* [Step - Direct mode](#step---direct-mode)
* [Step - Use flashRDBOX from Docker container](#step---use-flashrdbox-from-docker-container)
   - [1) Prepare a Docker container image of flashRDBOX](#1-prepare-a-docker-container-image-of-flashrdbox)
      - [1-a) Create Docker container image](#1-a-create-docker-container-image)
      - [1-b) Pull Docker container image](#1-b-pull-docker-container-image)
   - [2) Run flashRDBOX from Docker container](#2-run-flashrdbox-from-docker-container)
      - [2-a) Set and execute each time from the initial state](#2-a-set-and-execute-each-time-from-the-initial-state)
      - [2-b) Change and execute as needed based on the previous settings](#2-b-change-and-execute-as-needed-based-on-the-previous-settings)
* [Sample of user-data.params](#sample-of-user-dataparams)


## Prepare
### OverView
**First of all, work after becoming the root account as follows.**  
```bash
$ sudo su -
[sudo] password for <user>: XXXXX
#
```

Processing of **flashRDBOX.sh**)  
`Usage: ./flashRDBOX.sh [-s] [-u user-data.params] [-n hostname] -p ssh-pubkey-file -k ssh-key-file <SD image file>`  

Underlined parameters are specified on the command line of flashRDBOX.sh.
```
                              --- [flashRDBOX.sh] ---

[create-user-data-params.pl] <== <INTERACTIVE INPUT>
         ^
         |
         v
<user-data.params> ---
 ~~~~~~~~~~~~~~~~     |
                      |----> [create-user-data-yaml.pl] ---> user-data.yml ---> [flash] ---> <SD card>
                      |                                        (created)           ^         (writed)
  user-data.yml.in ---                                                             |             ^
                                                                                   |             |
<hostname> ------------------------------------------------------------------------              |
 ~~~~~~~~                                                                          |             |
<SD image file> -------------------------------------------------------------------              |
 ~~~~~~~~~~~~~                                                                                   |
<ssh-pubkey-file> -------------------------------------------------------------------------------
 ~~~~~~~~~~~~~~~                                                                                 |
<ssh-key-file> ----------------------------------------------------------------------------------
 ~~~~~~~~~~~~
```

### 1) Prepare a Linux PC (Ubuntu/Debian) that has flash installed and can use an SD card adapter to write to the SD card

### 2) Install the following tools to work together
Use the following commands. If these commands do not exist, the packages will be installed automatically.  
```bash
# Install Depend
sudo apt-get install -y \
               sudo \
               unzip \
               file \
               hdparm \
               pv \
               udev \
               curl \
               uuid-runtime \
               whois \
               wpasupplicant

# Install hypriot/flash
curl -LO https://github.com/hypriot/flash/releases/download/2.3.0/flash
chmod +x flash
sudo mv flash /usr/local/bin/flash
```

 `- sudo -           # apt-get install sudo`  
 `- unzip -          # apt-get install unzip`  
 `- file -           # apt-get install file`  
 `- hdparm -         # apt-get install hdparm`  
 `- pv -             # apt-get install pv`  
 `- udevadm -        # apt-get install udev`  
 `- curl -           # apt-get install curl`  
 `- uuidgen -        # apt-get install uuid-runtime`  
 `- mkpasswd -       # apt-get install whois`  
 `- wpa_passphrase - # apt-get install wpasupplicant`  
 `- hypriot/flash`  

### 3) git clone flashRDBOX
```bash
# git clone https://github.com/rdbox-intec/flashRDBOX.git
```

### 4) Prepare the ssh key pair files (public key / private key) for the account specified by USER_NAME

### 5) Determine the hostname
Specify with the -n option or specify interactively.
For interactive mode, select the host type from the following and specify suffix string.
```
host type:
0. other
1. master
2. slave
3. vpnbridge
What number do you select? [0-3]
```
```
suffix? 
```
If `0. other` is selected, any host name can be specified. This is the same as the -n option.
For example, if you select `1. master` as host type and `00` as suffix, the host name becomes `rdbox-master-00`.

## Step - Interactive mode (default)

### 1) Copy the template file (user-data.params) of parameters for RDBOX SD image file
Copy `conf/user-data.params.sample` to `user-data.params` file in the same directory.
```bash
# cd flashRDBOX/conf
# cp user-data.params.sample user-data.params
```

### 2) Execute flashRDBOX.sh and write the SD image file to the SD card
Set the value of each item interactively with the value of each item of the current user-data.params as the default.
After updating user-data.params, the writing process to the SD card is continued.  
```bash
# cd flashRDBOX/bin
# ./flashRDBOX.sh -p id_rsa.pub -k id_rsa <SD image file>
```
## Step - Direct mode

If this conf/user-data.yml already exists, you can skip interactive mode with the -s option and use user-data.yml as it is.  
```bash
# cd flashRDBOX/bin
# ./flashRDBOX.sh -s -p id_rsa.pub -k id_rsa <SD image file>
```   

## Step - Use flashRDBOX from Docker container
You can execute flashRDBOX from the container in interactive mode or direct mode, as needed.
For `<ssh-pubkey-file>`, `<ssh-key-file>` and `<SD image file>` files, specify the file path on the host machine.

### 1) Prepare a Docker container image of flashRDBOX
#### 1-a) Create Docker container image
Build a container image of flashRDBOX based on Dockerfile.
```bash
# docker build -t rdbox/flash-rdbox -f Dockerfile .
```

#### 1-b) Pull Docker container image
Get a container image of flashRDBOX from Dockerhub.
```bash
# docker pull rdbox/flash-rdbox
```

### 2) Run flashRDBOX from Docker container
#### 2-a) Set and execute each time from the initial state
This is an example of mounting ssh key and SD image file to the directory `/opt/flashRDBOX/bin` where flashRDBOX.sh is located.
Every time, it is a style to set from the initial state.   
  
**Execute flashRDBOX**  
```bash
# docker run --entrypoint /opt/flashRDBOX/bin/flashRDBOX.sh -v <ssh-pubkey-file>:/opt/flashRDBOX/bin/id_rsa.pub:ro -v <ssh-key-file>:/opt/flashRDBOX/bin/id_rsa:ro -v <SD image file>:/opt/flashRDBOX/bin/rdbox.img:ro --privileged -it rdbox/flash-rdbox:latest -p id_rsa.pub -k id_rsa rdbox.img
```

#### 2-b) Change and execute as needed based on the previous settings
This is an example of mounting ssh key and SD image file to the directory /opt/flashRDBOX/bin where flashRDBOX.sh is located.
You can change it based on the settings written to the SD card last time.   
  
**Run the container only once at the beginning**  
```bash
# docker run -v <ssh-pubkey-file>:/opt/flashRDBOX/bin/id_rsa.pub:ro -v <ssh-key-file>:/opt/flashRDBOX/bin/id_rsa:ro -v <SD image file>:/opt/flashRDBOX/bin/rdbox.img:ro --privileged -dit --name "flashRDBOX" rdbox/flash-rdbox:latest
```
  
**Execute flashRDBOX each time**  
```bash
# docker exec -it flashRDBOX /opt/flashRDBOX/bin/flashRDBOX.sh -p id_rsa.pub -k id_rsa rdbox.img
```

## Sample of user-data.params
```conf
#--------------------------------------------------------
# RDBOX common account information
#--------------------------------------------------------

# User name commonly used on machines on RDBOX network
USER_NAME=ubuntu

# [Change] Password for account 'ubuntu'
USER_PASSWD=

# [Change] SSH public key for account 'ubuntu'
USER_SSH_AUTHORIZED_KEYS=

#--------------------------------------------------------
# OS information
#--------------------------------------------------------

# [Confirmation] OS locale
LOCALE=ja_JP.UTF-8

# [Confirmation] OS timezone
TIMEZONE=Asia/Tokyo

# [Confirmation] NTP server pool list (comma delimited)
NTP_POOLS=0.debian.pool.ntp.org,1.debian.pool.ntp.org,2.debian.pool.ntp.org,3.debian.pool.ntp.org

# [Confirmation] NTP server list (comma delimited)
NTP_SERVERS=ntp.nict.jp

#--------------------------------------------------------
# Wi-Fi information
#--------------------------------------------------------

# for /etc/rdbox/wpa_supplicant_be.conf, /etc/rdbox/hostapd_be.conf
# [Change] SSID
BE_SSID=
# [Change] Password
BE_PASSWD=
# [Automatic calculation] Pre shared key
BE_PSK=

# for /etc/rdbox/wpa_supplicant_ap_bg.conf, /etc/rdbox/hostapd_ap_bg.conf
# [Change] SSID
AP_BG_SSID=
# [Change] Password
AP_BG_PASSWD=
# [Automatic calculation] Pre shared key
AP_BG_PSK=

# for /etc/rdbox/hostapd_ap_an.conf
# [Change] SSID
AP_AN_SSID=
# [Change] Password
AP_AN_PASSWD=
# [Automatic calculation] Pre shared key
AP_AN_PSK=

#--------------------------------------------------------
# VPN information
#--------------------------------------------------------

# [Change] VPN server address
VPN_SERVER_ADDRESS=

# VPN hub name
VPN_HUB_NAME=rdbox

# [Change] Username for connecting to the VPN server
VPN_USER_NAME=

# [Change] Password for connecting to the VPN server
VPN_USER_PASS=

#--------------------------------------------------------
# Configure the transparent proxy service. (if necessary)
# Please do not change if you do not use proxy service.
#--------------------------------------------------------

# For http_proxy, specify the address of the proxy server of your organization starting with http.
# Exapmle)
#   HTTP_PROXY=http://user:pass@yourproxyserver.com:8080
HTTP_PROXY=

# For no_proxy, you need to access directly for internal. Also you can use IP Address, CIDR in no_proxy. (comma delimited)
# Exapmle)
#   NO_PROXY=192.168.179.0/24,10.244.0.0/16
NO_PROXY=

#--------------------------------------------------------
# Arguments for kubeadm join <ARGS>
#--------------------------------------------------------

# [Change]
# You join k8s cluster, you need strings from kubeadmn init.
#
# [...]
# You can now join any number of machines by running the following on each node
# as root:
#   kubeadm join 192.168.179.2:6443 --token 2tswmw.tf3q52bo2fs1pz24 --discovery-token-ca-cert-hash sha256:78c3ac3a493c0147b28e8b4b478e41f7e6493806099fa74545808384eca78b11
#                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ This args is string after "kubeadm join "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# [...]
KUBEADM_JOIN_ARGS=
```

## License

MIT - see the [LICENSE](./LICENSE) file for details.
