# Automaticlly install pptpd on Amazon EC2 Ubuntu 12.04 LTS
#
# You need to adjust your "Security Groups"  to allow 1723
# My security rules looks like:
# =================================
# ALL  tcp  0  65535 0.0.0.0/0
# ALL  udp  0  65535 0.0.0.0/0
# ICMP echo          0.0.0.0/0
# =================================
#
# Authors: dongxf@gmail.com
# Version: 0.1
# URL: http://dongxf.sowact.com/

#echo "[ Clear previous settting... ]"
#apt-get -y remove pptpd ppp
#iptables --flush POSTROUTING --table nat
#iptables --flush FORWARD
#rm -rf /etc/pptpd.conf
#rm -rf /etc/ppp

echo "[ Install packages... ]"
#mkdir ~/src
#cd ~/src
#wget http://www.bradiceanu.net/files/pptpd-1.3.4-1.fc12.src.rpm
#rpmbuild --rebuild pptpd-1.3.4-1.fc12.src.rpm
#rpm -i ../rpmbuild/RPMS/i686/pptpd-1.3.4-1.amzn1.i386.rpm
#apt-get update
apt-get -y install chkconfig pptpd ppp

echo "[ Allocate ip to vpn clients... ]"
sed -i 's/^logwtmp/#logwtmp/g' /etc/pptpd.conf
echo "localip 10.64.64.1" >> /etc/pptpd.conf
echo "remoteip 10.64.64.2-100" >> /etc/pptpd.conf

echo "[ Setup ipv4 forwarding... ]"
sed -i 's/^net.ipv4.ip_forward/#net.ipv4.ip_forward/g' /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

echo "[ Setup dns... ]"
echo "ms-dns 8.8.8.8" >> /etc/ppp/pptpd-options
echo "ms-dns 8.8.4.4" >> /etc/ppp/pptpd-options

echo "[ Generating password for vpn client... ]"
pass=`openssl rand 8 -base64`
if [ "$1" != "" ]
then pass=$1
fi
echo "vpn pptpd ${pass} *" >> /etc/ppp/chap-secrets
echo "dongxy pptpd luckyhouse123 *" >> /etc/ppp/chap-secrets
echo "dongxf pptpd luckyhouse123 *" >> /etc/ppp/chap-secrets
echo "x201i pptpd luckyhouse123 *" >> /etc/ppp/chap-secrets
echo "carify pptpd forevereedom *" >> /etc/ppp/chap-secrets


echo "[ Change iptables... ]"
src_ip=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk 'NR==1 { print $1}'`
iptables -t nat -A POSTROUTING -s 10.64.64.0/24 -j SNAT --to-source $src_ip
iptables -A FORWARD -p tcp --syn -s 10.64.64.0/24 -j TCPMSS --set-mss 1356
iptables-save > /etc/iptables_up.rules
echo "pre-up iptables-restore < /etc/iptables_up.rules" >> /etc/network/interfaces

echo "[ Enable and start pptpd service ... ]"
#chkconfig iptables on
chkconfig pptpd on
service pptpd start

echo -e "\nDarling, pptpd service has been installed & enabled,  default client is \033[1mvpn\033[0m, password is \033[1m${pass}\033[1m"
echo -e "Please using telnet www.yourdomain.com 1723 to verify your Security Groups settings"
