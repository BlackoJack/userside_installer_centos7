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
	rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 > /dev/null
	yum -y -q install expect dialog wget sudo > /dev/null
}

install_epel(){
	yum -y -q install epel-release &> /dev/null
	rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 > /dev/null
}

install_webtatic(){
	yum -y -q install https://mirror.webtatic.com/yum/el7/webtatic-release.rpm > /dev/null
	rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-webtatic-el7 > /dev/null
}

install_php7_apache(){
	yum install -y -q php71w mod_php71w php71w-cli php71w-common php71w-gd php71w-mbstring php71w-mcrypt php71w-mysqlnd php71w-xml php71w-intl php71w-pdo php71w-snmp php71w-xml php71w-soap php71w-pgsql > /dev/null
}

install_apache(){
	yum -y -q install httpd > /dev/null
}

install_mysql(){
	yum -y -q install https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm > /dev/null
	rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql > /dev/null
	rm -f mysql57-community-release-el7-11.noarch.rpm
	yum -y -q install mysql-server > /dev/null
	echo 'max_allowed_packet = 10M' >> /etc/my.cnf
}

install_postgres(){
	yum -y -q install https://download.postgresql.org/pub/repos/yum/testing/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm > /dev/null
	rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-PGDG-10 > /dev/null
	yum -y -q install postgresql10 postgresql10-server > /dev/null
	/usr/pgsql-10/bin/postgresql-10-setup initdb > /dev/null
}

install_postgis(){
	yum -y -q install postgis2_10 > /dev/null
}

install_userside(){
	cd /var/www/userside && php -r "copy('http://my.userside.eu/install', 'userside_install.phar');"
	echo "Начинается установка UserSide. Базы находятся локально (host: localhost). Имена баз данных - userside (В postgres и в MySQL). Пароли были заданы ранее"
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
	systemctl enable httpd > /dev/null
}

enable_mysql(){
	systemctl enable mysqld > /dev/null
}

enable_postgres(){
	systemctl enable postgresql-10 > /dev/null
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
   ServerAdmin webmaster@yourdomain.name
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
	systemctl start mysqld > /dev/null
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
    spawn sudo -u postgres createuser userside -P
    expect "Enter password for new role:"
    send "$psql_passwd\n"
    expect "Enter it again:"
    send "$psql_passwd\n"
    expect eof
EOF
	sudo -u postgres createdb -e -E "UTF-8" -l "ru_RU.UTF-8" -O userside -T template0 userside > /dev/null
	sudo -u postgres psql -d userside -c "CREATE EXTENSION postgis" > /dev/null
}

settings_mysql(){
	grep 'temporary password' /var/log/mysqld.log
	echo "Введите временный пароль от MySQL (строчка выше), а потом задайте и запомните сложный!!! пароль (какого-то хера четыре раза)"
	mysql_secure_installation -p
	echo "Введите ваш пароль от MySQL"
	mysql -uroot -p -e "CREATE DATABASE \`userside\` CHARACTER SET utf8 COLLATE utf8_general_ci;"
}

settings_crontab(){
	echo '* * * * *   www-data   php /var/www/userside/userside cron > /dev/null 2>&1'  >> /etc/crontab
}

	domain="userside.sibdata.ru"
	read -e -i "$domain" -p "Укажите домен сайта Userside: " input_domain
	domain="${input_domain:-$domain}"

	psql_passwd="ChangeMeNow"
	read -e -i "$psql_passwd" -p "Укажите пароль Postgres: " input_psql_passwd
	psql_passwd="${input_psql_passwd:-$psql_passwd}"

printf 'Выполняется установка и настройка компонентов '
spinner &

set_lang
install_all
enable_all
site_add $domain
run_all
settings_postgres $psql_passwd
settings_crontab


kill "$!" > /dev/null # kill the spinner
printf '\n'

settings_mysql
install_userside
