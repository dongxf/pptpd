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
# Version: 0.2
# URL: http://dongxf.sowact.com/

echo "[ Install packages... ]"
apt-get -y install bcrelay pptpd

backup_dir=/etc/backup.install-pptpd.`date +%Y%m%d%H%M%S`
mkdir $backup_dir

echo "[ Allocate ip to vpn clients... ]"
cp /etc/pptpd.conf $backup_dir/pptpd.conf.before
sed -i 's/^logwtmp/#logwtmp/g' /etc/pptpd.conf
sed -i 's/^localip/#localip/g' /etc/pptpd.conf
sed -i 's/^remoteip/#remoteip/g' /etc/pptpd.conf
echo "localip 10.64.64.1" >> /etc/pptpd.conf
echo "remoteip 10.64.64.2-100" >> /etc/pptpd.conf
cp /etc/pptpd.conf $backup_dir/pptpd.conf.after

echo "[ Setup ipv4 forwarding... ]"
cp /etc/sysctl.conf $backup_dir/sysctrl.conf.before
sed -i 's/^net.ipv4.ip_forward/#net.ipv4.ip_forward/g' /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
cp /etc/sysctl.conf $backup_dir/sysctrl.conf.after
sysctl -p

echo "[ Setup dns... ]"
cp /etc/ppp/pptpd-options $backup_dir/pptpd-options.before
sed -i 's/^ms-dns /#ms-dns /g' /etc/ppp/pptpd-options
echo "ms-dns 8.8.8.8" >> /etc/ppp/pptpd-options
echo "ms-dns 8.8.4.4" >> /etc/ppp/pptpd-options
cp /etc/ppp/pptpd-options $backup_dir/pptpd-options.after

echo "[ Generating password for vpn client... ]"
cp /etc/ppp/chap-secrets $backup_dir/chap-secrets.before
pass=`openssl rand 8 -base64`
if [ "$1" != "" ]
then pass=$1
fi
echo "vpn pptpd ${pass} *" >> /etc/ppp/chap-secrets
cp /etc/ppp/chap-secrets $backup_dir/chap-secrets.after

echo "[ Change iptables... ]"
iptables-save > $backup_dir/iptables.dump.before
src_ip=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk 'NR==1 { print $1}'`
iptables -t nat -A POSTROUTING -s 10.64.64.0/24 -j SNAT --to-source $src_ip
iptables -A INPUT -p tcp -m tcp --dport 1723 -j ACCEPT
iptables -A FORWARD -p tcp --syn -s 10.64.64.0/24 -j TCPMSS --set-mss 1356
iptables -A INPUT -p gre -j ACCEPT
iptables-save > $backup_dir/iptables.dump.after
sed -i 's/:FORWARD DROP/:FORWARD ACCEPT/g' $backup_dir/iptables.dump.after
iptables-restore < $backup_dir/iptables.dump.after
if [ -f /etc/default/iptables ]; then
  cp /etc/default/iptables $backup_dir/iptables.before
  cp $backup_dir/iptables.dump.after /etc/default/iptables
  cp /etc/default/iptables $backup_dir/iptables.after
else
  cp /etc/network/interfaces $backup_dir/interfaces.before
  echo "pre-up iptables-restore < $backup_dir/iptables_up.dump.after" >> /etc/network/interfaces
  cp /etc/network/interfaces $backup_dir/interfaces.after
fi

echo "[ Enable and start pptpd service ... ]"
update-rc.d pptpd enable
service iptables restart
service pptpd start

echo -e "\nDarling, pptpd service has been installed & enabled,  default client is \033[42;37mvpn\033[0m, password is \033[44;31m${pass}\033[0m"
echo -e "Please using telnet www.yourdomain.com 1723 to verify your Security Groups settings"
