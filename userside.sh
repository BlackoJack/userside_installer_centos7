#!/bin/bash
#
# Скрипт установки Userside
#

spinner() {
    local i sp n
    sp='/-\|'
    n=${#sp}
    printf ' '
    while sleep 0.1; do
        printf "%s\b" "${sp:i++%n:1}"
    done
}

install_utils(){
	yum -y -q install expect dialog wget sudo
}

install_epel(){
	yum -y -q install epel-release
}

install_webtatic(){
	yum -y -q install https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
}

install_php7_apache(){
	yum install -y -q php71w mod_php71w php71w-cli php71w-common php71w-gd php71w-mbstring php71w-mcrypt php71w-mysqlnd php71w-xml php71w-intl php71w-pdo php71w-snmp php71w-xml php71w-soap php71w-pgsql
}

install_apache(){
	yum -y -q install httpd
}

install_mysql(){
  cat <<EOF > /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
  	yum -y -q install MariaDB-server MariaDB-client
}

install_postgres(){
	yum -y -q install https://download.postgresql.org/pub/repos/yum/testing/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm
	yum -y -q install postgresql10 postgresql10-server
	/usr/pgsql-10/bin/postgresql-10-setup initdb
}

install_postgis(){
	yum -y -q install postgis2_10
}

install_userside(){
	cd /var/www/userside && php -r "copy('http://my.userside.eu/install', 'userside_install.phar');"
    echo "Воспользуйтесь этими данными, для установки Userside:"
	echo "Хост MySQL: localhost"
    echo "Порт MySQL: 3306"
    echo "Пользователь MySQL: "$mysql_user
    echo "Пароль MySQL: "$mysql_passwd
    echo "База MySQL: "$mysql_db
    echo "Хост Postgres: localhost"
    echo "Порт Postgres: 5042"
    echo "Пользователь Postgres: "$psql_user
    echo "Пароль Postgres: "$psql_passwd
    echo "База Postgres: "$psql_db
	cd /var/www/userside && php userside_install.phar
	chown -hR apache:apache /var/www/userside > /dev/null
}

install_all(){
	install_utils
	install_epel
	install_webtatic
	install_apache
	install_php7_apache
	install_mysql
	install_postgres
	install_postgis
}

enable_apache(){
	systemctl enable httpd
}

enable_mysql(){
	systemctl enable mariadb
}

enable_postgres(){
	systemctl enable postgresql-10
}

enable_all(){
enable_apache
enable_mysql
enable_postgres
}

site_add(){
	mkdir -p /var/www/userside > /dev/null
	cat <<EOF > /etc/httpd/conf.d/userside.conf
<VirtualHost *:80>
   ServerAdmin $admin_email
   DocumentRoot "/var/www/userside"
   ServerName $domain
   ErrorLog "/var/log/httpd/userside-main-error.log"
   CustomLog "/var/log/httpd/userside-main-access.log" common
   <Directory "/var/www/userside">
       Options -Indexes
       AllowOverride All
       Require all granted
   </Directory>
</VirtualHost>
EOF
}

run_apache(){
	systemctl start httpd > /dev/null
}

run_mysql(){
	systemctl start mariadb > /dev/null
}

run_postgres(){
	systemctl start postgresql-10 > /dev/null
}

run_all(){
run_apache
run_mysql
run_postgres
}

set_lang(){
	localedef -i ru_RU -f UTF-8 ru_RU.UTF-8 > /dev/null
	localectl set-locale LANG=ru_RU.UTF-8 > /dev/null
}

settings_postgres(){
/usr/bin/expect<<EOF
    log_user 0
    spawn sudo -u postgres createuser $psql_user -P
    expect "Enter password for new role:"
    send "$psql_passwd\n"
    expect "Enter it again:"
    send "$psql_passwd\n"
    expect eof
EOF
	sudo -u postgres createdb -e -E "UTF-8" -l "ru_RU.UTF-8" -O $psql_user -T template0 $psql_db > /dev/null
	sudo -u postgres psql -d $psql_db -c "CREATE EXTENSION postgis" > /dev/null
}

settings_mysql(){

	mysqladmin -u root password $mysql_root_passwd

/usr/bin/expect<<EOF
    log_user 0
    spawn mysql -uroot -p -e "CREATE DATABASE \`$mysql_db\` CHARACTER SET utf8 COLLATE utf8_general_ci; CREATE USER '$mysql_user'@'localhost' IDENTIFIED BY '$mysql_passwd'; GRANT ALL PRIVILEGES ON \`$mysql_db\` . * TO '$mysql_user'@'localhost'; FLUSH PRIVILEGES;"
    expect "Enter password:"
    send "$mysql_root_passwd\n"
    expect eof
EOF

}

settings_crontab(){
	echo '* * * * *   www-data   php /var/www/userside/userside cron > /dev/null 2>&1'  >> /etc/crontab
}

	domain="userside.sibdata.ru"
	read -e -i "$domain" -p "Домен сайта Userside: " input_domain
	domain="${input_domain:-$domain}"
    
    admin_email="admin@sibdata.ru"
	read -e -i "$admin_email" -p "E-Mail администратора: " input_admin_email
	admin_email="${input_admin_email:-$admin_email}"
    
    psql_user="userside"
	read -e -i "$psql_user" -p "Пользователь Postgres: " input_psql_user
	psql_user="${input_psql_user:-$psql_user}"
    
    psql_db="userside"
	read -e -i "$psql_db" -p "База Postgres: " input_psql_db
	psql_db="${input_psql_db:-$psql_db}"

	psql_passwd="ChangeMeNow"
	read -e -i "$psql_passwd" -p "Пароль Postgres: " input_psql_passwd
	psql_passwd="${input_psql_passwd:-$psql_passwd}"
    
    mysql_root_passwd="ChangeMeNow"
	read -e -i "$mysql_root_passwd" -p "Пароль root-а MySQL: " input_mysql_root_passwd
	mysql_root_passwd="${input_mysql_root_passwd:-$mysql_root_passwd}"
    
    mysql_user="userside"
	read -e -i "$mysql_user" -p "Пользователь MySQL: " input_mysql_user
	mysql_user="${input_mysql_user:-$mysql_user}"
    
    mysql_db="userside"
	read -e -i "$mysql_db" -p "База MySQL: " input_mysql_db
	mysql_db="${input_mysql_db:-$mysql_db}"

    mysql_passwd="ChangeMeNow"
	read -e -i "$mysql_passwd" -p "Пароль пользователя MySQL: " input_mysql_passwd
	mysql_passwd="${input_mysql_passwd:-$mysql_passwd}"

printf 'Выполняется установка и настройка компонентов '
spinner &

set_lang
install_all &> /dev/null
enable_all &> /dev/null
site_add $domain $admin_email
run_all
settings_postgres $psql_user $psql_passwd $psql_db
settings_mysql $mysql_user $mysql_root_passwd $mysql_passwd $mysql_db
settings_crontab

kill "$!" > /dev/null # kill the spinner
printf '\n'

install_userside $psql_user $psql_passwd $psql_db $mysql_user $mysql_passwd $mysql_db
