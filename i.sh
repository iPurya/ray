#!/bin/bash
set -e
HC='\033[1;32m'
NC='\033[0m'
echo ""
read -e -p " [?] Enter your domain or subdomain: " MYDOMAIN
MYDOMAIN=$(echo "$MYDOMAIN" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
[[ -z "$MYDOMAIN" ]] && { echo "Error: Domain URL is needed."; exit 1; }

echo -e "\n$HC+$NC Checking IP <=> Domain..."
RESIP=$(dig +short "$MYDOMAIN" | grep '^[.0-9]*$' || echo 'NONE')
SRVIP=$(curl -qs http://checkip.amazonaws.com  | grep '^[.0-9]*$' || echo 'NONE')

if [ "$RESIP" = "$SRVIP" ]; then
    echo -e "\n$HC+$NC $RESIP => $MYDOMAIN is valid."
else
    echo -e "\033[1;31m -- Error: \033[0m Server IP is $HC$SRVIP$NC but '$MYDOMAIN' resolves to \033[1;31m$RESIP$NC\n"
    echo -e "If you have just updated the DNS record, wait a few minutes and then try again. \n"
    exit;
fi

FLAGFILE=running.flag
echo ".">$FLAGFILE
function cleanup {
    [[ ! -f $FLAGFILE ]] && exit;
    echo -e "\033[1;31m -- Error log: \033[0m "
    tail -n 10 2.log
    tail -n 5 1.log
}
trap cleanup EXIT

MYUSER=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-12} | head -n 1)
MYPORT=$(shuf -i 2023-64999 -n1)
MYPASS=$(cat /dev/urandom | tr -dc '[:alpha:]0-9' | fold -w ${1:-40} | head -n 1)
TNAME=$(cat /dev/urandom | tr -dc '[:alpha:]0-9' | fold -w ${1:-12} | head -n 1)
TPASS=$(cat /dev/urandom | tr -dc '[:alpha:]0-9' | fold -w ${1:-12} | head -n 1)
TPORT=443
NOW=$(date +"%T")

HASXUI=$(which x-ui || echo "")
if [ ! -z "$HASXUI" ]; then
    echo -e "\n$HC+$NC Cleaning Previous xu-i...\n"
    (echo "y" | x-ui uninstall) 2>> 2.log 1>> 1.log
    echo -e "\n$HC+$NC Removing $HASXUI...\n"
    rm "$HASXUI" -f
fi

echo -e "\n * $NOW - Setting up $MYDOMAIN\n\n">1.log
echo -e "\n * $NOW - Setting up $MYDOMAIN\n\n">2.log
echo -e "\n$HC***$NC $NOW - Setting up $MYDOMAIN"

echo -e "\n$HC+$NC Installing certbot..."
snap install core 2>> 2.log 1>> 1.log
snap refresh core 2>> 2.log 1>> 1.log
snap install --classic certbot 2>> 2.log 1>> 1.log
ln -s /snap/bin/certbot /usr/bin/certbot 2>> 2.log 1>> 1.log || true

echo -e "\n$HC+$NC Issuing SSL certificate..."
certbot certonly --standalone -d $MYDOMAIN --register-unsafely-without-email --non-interactive --agree-tos 2>> 2.log 1>> 1.log


echo -e "\n$HC+$NC Installing xray and x-ui..."
wget https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh --no-check-certificate  2>> 2.log 1>> 1.log
chmod +x install.sh 2>> 2.log 1>> 1.log

echo "y
$MYUSER
$MYPASS
$MYPORT
" | ./install.sh 2>> 2.log 1>> 1.log

echo -e "\n$HC+$NC Configuring firewall..."
ufw status 2>> 2.log 1>> 1.log
echo "y" | ufw reset 2>> 2.log 1>> 1.log
ufw status 2>> 2.log 1>> 1.log
ufw default allow outgoing 2>> 2.log 1>> 1.log
ufw default deny incoming 2>> 2.log 1>> 1.log
ufw allow ssh 2>> 2.log 1>> 1.log
ufw allow 80 2>> 2.log 1>> 1.log
ufw allow $TPORT 2>> 2.log 1>> 1.log
ufw deny $MYPORT 2>> 2.log 1>> 1.log
echo "y" | ufw enable 2>> 2.log 1>> 1.log

echo -e "\n$HC+$NC Creating the config..."

curl --cookie-jar cookies.txt "http://$MYDOMAIN:$MYPORT/login" --data-raw "username=$MYUSER&password=$MYPASS" 2>> 2.log 1>> 1.log
curl --cookie cookies.txt "http://$MYDOMAIN:$MYPORT/xui/inbound/add" --data-raw "up=0&down=0&total=0&remark=$TNAME&enable=true&expiryTime=0&listen=&port=$TPORT&protocol=trojan&settings=%7B%22clients%22%3A%5B%7B%22password%22%3A%22$TPASS%22%2C%22flow%22%3A%22xtls-rprx-direct%22%7D%5D%2C%22fallbacks%22%3A%5B%5D%7D&streamSettings=%7B%22network%22%3A%22tcp%22%2C%22security%22%3A%22tls%22%2C%22tlsSettings%22%3A%7B%22serverName%22%3A%22$MYDOMAIN%22%2C%22certificates%22%3A%5B%7B%22certificateFile%22%3A%22%2Fetc%2Fletsencrypt%2Flive%2F$MYDOMAIN%2Ffullchain.pem%22%2C%22keyFile%22%3A%22%2Fetc%2Fletsencrypt%2Flive%2F$MYDOMAIN%2Fprivkey.pem%22%7D%5D%7D%2C%22tcpSettings%22%3A%7B%22header%22%3A%7B%22type%22%3A%22none%22%7D%7D%7D&sniffing=%7B%22enabled%22%3Atrue%2C%22destOverride%22%3A%5B%22http%22%2C%22tls%22%5D%7D" 2>> 2.log 1>> 1.log


echo -e "\nPANEL: http://$MYDOMAIN:$MYPORT" > panel.txt
echo -e "\nUSER: $MYUSER" >> panel.txt
echo -e "\nPASS: $MYPASS" >> panel.txt
echo -e "\nConfig: trojan://$TPASS@$MYDOMAIN:$TPORT#$TNAME" >> panel.txt
echo -e "\nPublic Key:  /etc/letsencrypt/live/$MYDOMAIN/fullchain.pem" >> panel.txt
echo -e "\nPrivate Key: /etc/letsencrypt/live/$MYDOMAIN/privkey.pem" >> panel.txt

echo -e "\n \e[1;30;106m[\xE2\x9C\x94]$NC - \e[1m Proxy Config: $HC trojan://$TPASS@$MYDOMAIN:$TPORT#$TNAME $NC\n\n \e[2m *** Good luck. *** $NC  \e[1;30;46m(⌐■_■)$NC \n\n"
rm -f "$FLAGFILE"
rm -f cookies.txt
