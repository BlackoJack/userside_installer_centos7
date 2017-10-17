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
  cat <<EOF > /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
	rpm --quiet --import https://yum.mariadb.org/RPM-GPG-KEY-MariaDB > /dev/null
  	yum -y -q install MariaDB-server MariaDB-client > /dev/null
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
	systemctl enable mariadb > /dev/null
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
    spawn sudo -u postgres createuser userside -P
    log_user 0
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

/usr/bin/expect<<EOF
spawn mysql_secure_installation
log_user 0
match_max 100000
expect -exact "\r
NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MariaDB\r
      SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!\r
\r
In order to log into MariaDB to secure it, we'll need the current\r
password for the root user.  If you've just installed MariaDB, and\r
you haven't set the root password yet, the password will be blank,\r
so you should just press enter here.\r
\r
Enter current password for root (enter for none): "
send -- "\r"
expect -exact "\r
OK, successfully used password, moving on...\r
\r
Setting the root password ensures that nobody can log into the MariaDB\r
root user without the proper authorisation.\r
\r
Set root password? \[Y/n\] "
send -- "Y\r"
expect -exact "Y\r
New password: "
send -- "$mysq_root_passwd\r"
expect -exact "\r
Re-enter new password: "
send -- "$mysq_root_passwd\r"
expect -exact "\r
Password updated successfully!\r
Reloading privilege tables..\r
 ... Success!\r
\r
\r
By default, a MariaDB installation has an anonymous user, allowing anyone\r
to log into MariaDB without having to have a user account created for\r
them.  This is intended only for testing, and to make the installation\r
go a bit smoother.  You should remove them before moving into a\r
production environment.\r
\r
Remove anonymous users? \[Y/n\] "
send -- "Y\r"
expect -exact "Y\r
 ... Success!\r
\r
Normally, root should only be allowed to connect from 'localhost'.  This\r
ensures that someone cannot guess at the root password from the network.\r
\r
Disallow root login remotely? \[Y/n\] "
send -- "Y\r"
expect -exact "Y\r
 ... Success!\r
\r
By default, MariaDB comes with a database named 'test' that anyone can\r
access.  This is also intended only for testing, and should be removed\r
before moving into a production environment.\r
\r
Remove test database and access to it? \[Y/n\] "
send -- "Y\r"
expect -exact "Y\r
 - Dropping test database...\r
 ... Success!\r
 - Removing privileges on test database...\r
 ... Success!\r
\r
Reloading the privilege tables will ensure that all changes made so far\r
will take effect immediately.\r
\r
Reload privilege tables now? \[Y/n\] "
send -- "Y\r"
expect eof
EOF

/usr/bin/expect<<EOF
    spawn mysql -uroot -p -e "CREATE DATABASE \`userside\` CHARACTER SET utf8 COLLATE utf8_general_ci;"
    log_user 0
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

	psql_passwd="ChangeMeNow"
	read -e -i "$psql_passwd" -p "Пароль Postgres(пользователь userside): " input_psql_passwd
	psql_passwd="${input_psql_passwd:-$psql_passwd}"
    
    mysql_root_passwd="ChangeMeNow"
	read -e -i "$mysql_root_passwd" -p "Пароль MySQL(пользователь root): " input_mysql_root_passwd
	mysql_root_passwd="${input_mysql_root_passwd:-$mysql_root_passwd}"

    mysql_passwd="ChangeMeNow"
	read -e -i "$mysql_passwd" -p "Пароль MySQL(пользователь userside): " input_mysql_passwd
	mysql_passwd="${input_mysql_passwd:-$mysql_passwd}"

printf 'Выполняется установка и настройка компонентов '
spinner &

set_lang
install_all
enable_all
site_add $domain $admin_email
run_all
settings_postgres $psql_passwd
settings_mysql $mysql_root_passwd $mysql_passwd
settings_crontab

kill "$!" > /dev/null # kill the spinner
printf '\n'

install_userside
