#!/bin/bash
# TimelockCoin Masternode Setup Script V2.1.1 for 18.04 Ubuntu LTS
#
# Script will attempt to autodetect primary public IP address
# and generate masternode private key unless specified in command line
#
# Usage:
# bash tymauto.sh
#

#Color codes
RED='\033[0;91m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#TCP port
PORT=4402
RPC=4401

#Clear keyboard input buffer
function clear_stdin { while read -r -t 0; do read -r; done; }

#Delay script execution for N seconds
function delay { echo -e "${GREEN}Sleep for $1 seconds...${NC}"; sleep "$1"; }

#Stop daemon if it's already running
function stop_daemon {
    if pgrep -x 'timelockcoind' > /dev/null; then
        echo -e "${YELLOW}Attempting to stop timelockcoind${NC}"
        timelockcoin-cli stop
        sleep 30
        if pgrep -x 'timelockcoind' > /dev/null; then
            echo -e "${RED}timelockcoind daemon is still running!${NC} \a"
            echo -e "${RED}Attempting to kill...${NC}"
            sudo pkill -9 timelockcoind
            sleep 30
            if pgrep -x 'timelockcoind' > /dev/null; then
                echo -e "${RED}Can't stop timelockcoind! Reboot and try again...${NC} \a"
                exit 2
            fi
        fi
    fi
}

#Process command line parameters
genkey=$1
clear

echo -e "${GREEN} ------- TimelockCoin MASTERNODE INSTALLER V2.1.1--------+
 |                                                  |
 |                                                  |::
 |       The installation will install and run      |::
 |        the masternode under a user TYM.         |::
 |                                                  |::
 |        This version of installer will setup      |::
 |           fail2ban and ufw for your safety.      |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::S${NC}"
echo "Do you want me to generate a masternode private key for you?[y/n]"
read DOSETUP

if [[ $DOSETUP =~ "n" ]] ; then
          read -e -p "Enter your private key:" genkey;
              read -e -p "Confirm your private key: " genkey2;
    fi

#Confirming match
  if [ $genkey = $genkey2 ]; then
     echo -e "${GREEN}MATCH! ${NC} \a" 
else 
     echo -e "${RED} Error: Private keys do not match. Try again or let me generate one for you...${NC} \a";exit 1
fi
sleep .5
clear

# Determine primary public IP address
dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils
publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ -n "$publicip" ]; then
    echo -e "${YELLOW}IP Address detected:" $publicip ${NC}
else
    echo -e "${RED}ERROR: Public IP Address was not detected!${NC} \a"
    clear_stdin
    read -e -p "Enter VPS Public IP Address: " publicip
    if [ -z "$publicip" ]; then
        echo -e "${RED}ERROR: Public IP Address must be provided. Try again...${NC} \a"
        exit 1
    fi
fi
if [ -d "/var/lib/fail2ban/" ]; 
then
    echo -e "${GREEN}Packages already installed...${NC}"
else
    echo -e "${GREEN}Updating system and installing required packages...${NC}"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get -y install wget nano
sudo apt-get install unzip
fi

#Generating Random Password for  JSON RPC
rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Create 2GB swap file
if grep -q "SwapTotal" /proc/meminfo; then
    echo -e "${GREEN}Skipping disk swap configuration...${NC} \n"
else
    echo -e "${YELLOW}Creating 2GB disk swap file. \nThis may take a few minutes!${NC} \a"
    touch /var/swap.img
    chmod 600 swap.img
    dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
    mkswap /var/swap.img 2> /dev/null
    swapon /var/swap.img 2> /dev/null
    if [ $? -eq 0 ]; then
        echo '/var/swap.img none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}Swap was created successfully!${NC} \n"
    else
        echo -e "${RED}Operation not permitted! Optional swap was not created.${NC} \a"
        rm /var/swap.img
    fi
fi
 
#Installing Daemon
cd ~
rm -rf /usr/local/bin/timelockcoin*
wget https://github.com/IDCHAINGROUP/TYM/releases/download/v2.1.1/tym-2.1.1-Ubuntu18.04-daemon.tar.gz
tar -xzvf tym-2.1.1-Ubuntu18.04-daemon.tar.gz
sudo chmod -R 755 timelockcoin-cli
sudo chmod -R 755 timelockcoind
cp -p -r timelockcoind /usr/local/bin
cp -p -r timelockcoin-cli /usr/local/bin

	
 timelockcoin-cli stop
 sleep 5
 #Create datadir
 if [ ! -f ~/.timelockcoin/timelockcoin.conf ]; then 
 	sudo mkdir ~/.timelockcoin
	
 fi

cd ~
clear
echo -e "${YELLOW}Creating timelockcoin.conf...${NC}"

# If genkey was not supplied in command line, we will generate private key on the fly
if [ -z $genkey ]; then
    cat <<EOF > ~/.timelockcoin/timelockcoin.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
server=1
daemon=1

EOF

    sudo chmod 755 -R ~/.timelockcoin/timelockcoin.conf

    #Starting daemon first time just to generate masternode private key
    timelockcoind
sleep 7
while true;do
    echo -e "${YELLOW}Generating masternode private key...${NC}"
    genkey=$(timelockcoin-cli createmasternodekey)
    if [ "$genkey" ]; then
        break
    fi
sleep 7
done
    fi
    
    #Stopping daemon to create timelockcoin.conf
    timelockcoin-cli stop
    sleep 5
cd ~/.timelockcoin && rm -rf blocks chainstate sporks
cd ~/.timelockcoin && wget https://github.com/IDCHAINGROUP/TYM/releases/download/v2.1.1/bootstrap.zip
cd ~/.timelockcoin && unzip bootstrap.zip
sudo rm -rf ~/.timelockcoin/bootstrap.tar.gz

	
# Create timelockcoin.conf
cat <<EOF > ~/.timelockcoin/timelockcoin.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
rpcallowip=127.0.0.1
rpcport=$RPC
port=$PORT
listen=1
server=1
daemon=1

logtimestamps=1
maxconnections=256
masternode=1
externalip=$publicip:$PORT
masternodeaddr=$publicip:$PORT
masternodeprivkey=$genkey
addnode=45.77.151.115
addnode=207.246.94.178
addnode=45.77.217.13
addnode=45.76.5.92
addnode=136.244.86.72
addnode=167.86.88.189
addnode=46.101.127.5


 
EOF
    timelockcoind -daemon
#Finally, starting daemon with new timelockcoin.conf
printf '#!/bin/bash\nif [ ! -f "~/.timelockcoin/timelockcoind.pid" ]; then /usr/local/bin/timelockcoind -daemon ; fi' > /root/tymauto.sh
chmod -R 755 /root/tymauto.sh
#Setting auto start cron job for TYM
if ! crontab -l | grep "tymauto.sh"; then
    (crontab -l ; echo "*/5 * * * * /root/tymauto.sh")| crontab -
fi

echo -e "========================================================================
${GREEN}Masternode setup is complete!${NC}
========================================================================
Masternode was installed with VPS IP Address: ${GREEN}$publicip${NC}
Masternode Private Key: ${GREEN}$genkey${NC}
Now you can add the following string to the masternode.conf file 
======================================================================== \a"
echo -e "${GREEN}TYM_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
echo -e "========================================================================
Use your mouse to copy the whole string above into the clipboard by
tripple-click + single-click (Dont use Ctrl-C) and then paste it 
into your ${GREEN}masternode.conf${NC} file and replace:
    ${GREEN}TYM_mn1${NC} - with your desired masternode name (alias)
    ${GREEN}TxId${NC} - with Transaction Id from getmasternodeoutputs
    ${GREEN}TxIdx${NC} - with Transaction Index (0 or 1)
     Remember to save the masternode.conf and restart the wallet!
To introduce your new masternode to the TYM network, you need to
issue a masternode start command from your wallet, which proves that
the collateral for this node is secured."

clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "Wait for the node wallet on this VPS to sync with the other nodes
on the network. Eventually the 'Is Synced' status will change
to 'true', which will indicate a comlete sync, although it may take
from several minutes to several hours depending on the network state.
Your initial Masternode Status may read:
    ${GREEN}Node just started, not yet activated${NC} or
    ${GREEN}Node  is not in masternode list${NC}, which is normal and expected.
"
clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "
${GREEN}...scroll up to see previous screens...${NC}
Here are some useful commands and tools for masternode troubleshooting:
========================================================================
To view masternode configuration produced by this script in timelockcoin.conf:
${GREEN}cat ~/.timelockcoin/timelockcoin.conf${NC}
Here is your timelockcoin.conf generated by this script:
-------------------------------------------------${GREEN}"
echo -e "${GREEN}TYM_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
cat ~/.timelockcoin/timelockcoin.conf
echo -e "${NC}-------------------------------------------------
NOTE: To edit timelockcoin.conf, first stop the timelockcoind daemon,
then edit the timelockcoin.conf file and save it in nano: (Ctrl-X + Y + Enter),
then start the timelockcoind daemon back up:
to stop:              ${GREEN}timelockcoin-cli stop${NC}
to start:             ${GREEN}timelockcoind${NC}
to edit:              ${GREEN}nano ~/.timelockcoin/timelockcoin.conf${NC}
to check mn status:   ${GREEN}timelockcoin-cli getmasternodestatus${NC}
========================================================================
To monitor system resource utilization and running processes:
                   ${GREEN}htop${NC}
========================================================================
"