#!/bin/bash

#this code is tested and fresh 2017-07-05-raspbian-jessie-lite image
#this code is tested and NOT WORKS with 2017-08-16-raspbian-stretch-lite image

#sudo su
#apt-get update -y && apt-get upgrade -y && apt-get install git -y
#git clone https://github.com/catonrug/raspbian-zabbix-3.git && cd raspbian-zabbix-3 && chmod +x agent-install.sh server-install.sh
#./server-install.sh

apt-get update -y && apt-get upgrade -y

# MySQL server will ask to create a password for root user.
# Enter your password when prompted.
apt-get install -y mysql-server mysql-client libmysqlclient-dev \
                        apache2 apache2-dev \
                        php5 php5-dev php5-gd php5-mysql \
                        fping libiksemel-dev libxml2-dev libsnmp-dev \
                        libssh2-1-dev libopenipmi-dev libcurl4-openssl-dev

printf "Type the password for user 'root' in mysql. Then press [ENTER]:"
read root_pwd

printf "\nType the password for user 'zabbix' in mysql. Then press [ENTER]:"
read zabbix_pwd

mysql -uroot -p$root_pwd <<QUERY_INPUT
create database zabbix character set utf8 collate utf8_bin;
grant all privileges on zabbix.* to zabbix@localhost identified by '$zabbix_pwd';
QUERY_INPUT
groupadd zabbix
useradd -g zabbix zabbix
mkdir -p /var/log/zabbix
chown -R zabbix:zabbix /var/log/zabbix/
mkdir -p /var/zabbix/alertscripts
mkdir -p /var/zabbix/externalscripts
chown -R zabbix:zabbix /var/zabbix/
tar -vzxf zabbix-*.tar.gz -C ~
cd ~/zabbix-*/database/mysql
mysql -uzabbix -p$zabbix_pwd zabbix < schema.sql &&
mysql -uzabbix -p$zabbix_pwd zabbix < images.sql &&
mysql -uzabbix -p$zabbix_pwd zabbix < data.sql &&
cd ~/zabbix-*/
./configure --enable-server --enable-agent --with-mysql --with-libcurl --with-libxml2 --with-ssh2 --with-net-snmp --with-openipmi --with-jabber
make install
cp ~/zabbix-*/misc/init.d/debian/* /etc/init.d/
update-rc.d zabbix-server defaults
update-rc.d zabbix-agent defaults
sed -i "s/^DBUser=.*$/DBUser=zabbix/" /usr/local/etc/zabbix_server.conf
sed -i "s/^.*DBPassword=.*$/DBPassword=$zabbix_pwd/" /usr/local/etc/zabbix_server.conf
sed -i "s/^.*FpingLocation=.*$/FpingLocation=\/usr\/bin\/fping/" /usr/local/etc/zabbix_server.conf
sed -i "s/^.*AlertScriptsPath=.*$/AlertScriptsPath=\/var\/zabbix\/alertscripts/" /usr/local/etc/zabbix_server.conf
sed -i "s/^.*ExternalScripts=.*$/ExternalScripts=\/var\/zabbix\/externalscripts/" /usr/local/etc/zabbix_server.conf
sed -i "s/^LogFile=.*$/LogFile=\/var\/log\/zabbix\/zabbix_server.log/" /usr/local/etc/zabbix_server.conf
mkdir /var/www/html/zabbix
cd ~/zabbix-*/frontends/php/
cp -a . /var/www/html/zabbix/
sed -i "s/^post_max_size = .*$/post_max_size = 16M/" /etc/php5/apache2/php.ini
sed -i "s/^max_execution_time = .*$/max_execution_time = 300/" /etc/php5/apache2/php.ini
sed -i "s/^max_input_time = .*$/max_input_time = 300/g" /etc/php5/apache2/php.ini
sed -i "s/^.*date.timezone =.*$/date.timezone = Europe\/Riga/g" /etc/php5/apache2/php.ini
sed -i "s/^.*always_populate_raw_post_data = .*$/always_populate_raw_post_data = -1/g" /etc/php5/apache2/php.ini
ipaddress=$(ifconfig | grep "inet.*addr.*Bcast.*Mask" | sed "s/  Bcast.*$//g" | sed "s/^.*://g")
cat > /var/www/html/zabbix/conf/zabbix.conf.php << EOF
<?php
// Zabbix GUI configuration file.
global \$DB;

\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = 'zabbix';
\$DB['PASSWORD'] = '$zabbix_pwd';

// Schema name. Used for IBM DB2 and PostgreSQL.
\$DB['SCHEMA'] = '';

\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = '$ipaddress';

\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
?>
EOF
#install additional debugging tools
#apt-get install mtr nmap dstat telnet python-mechanize python-requests -y

#reset ip address in config if sd card is moved to another raspberry
cat > /etc/network/if-up.d/zabbix-server-ip << EOF
#!/bin/sh
ipaddress=\$(ifconfig | grep "inet.*addr.*Bcast.*Mask" | sed "s/  Bcast.*\$//g" | sed "s/^.*://g")
sed -i "s/^\\\$ZBX_SERVER_NAME = .*$/\\\$ZBX_SERVER_NAME = \d039\`echo \$ipaddress\`\d039;/" /var/www/html/zabbix/conf/zabbix.conf.php
EOF
chmod +x /etc/network/if-up.d/zabbix-server-ip
