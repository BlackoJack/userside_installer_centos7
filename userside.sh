#!/bin/bash
#
# Скрипт установки Userside
#

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
  yum -y -q install https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm
  yum -y -q install postgresql10 postgresql10-server
  /usr/pgsql-10/bin/postgresql-10-setup initdb
}

install_postgis(){
  yum -y -q install postgis2_10
}

echo_settings(){
  LYELLOW='\033[1;33m'
  LGREEN='\033[1;32m'
  LRED='\033[1;31m'
  BGBLACK='\033[40m'
  NORMAL='\033[0m'

  echo ""
  echo -e "${BGBLACK}${LYELLOW}Воспользуйтесь этими данными, для установки Userside:${NORMAL}"
  echo -e "${BGBLACK}${LGREEN}Директория установки: "${LRED}$www_dir${NORMAL}
  echo -e "${BGBLACK}${LGREEN}Хост MySQL: ${LRED}localhost"${NORMAL}
  echo -e "${BGBLACK}${LGREEN}Порт MySQL: ${LRED}3306"${NORMAL}
  echo -e "${BGBLACK}${LGREEN}Пользователь MySQL: "${LRED}$mysql_user${NORMAL}
  echo -e "${BGBLACK}${LGREEN}Пароль MySQL: "${LRED}$mysql_passwd${NORMAL}
  echo -e "${BGBLACK}${LGREEN}База MySQL: "${LRED}$mysql_db${NORMAL}
  echo -e "${BGBLACK}${LGREEN}Хост Postgres: ${LRED}localhost"${NORMAL}
  echo -e "${BGBLACK}${LGREEN}Порт Postgres: ${LRED}5432"${NORMAL}
  echo -e "${BGBLACK}${LGREEN}Пользователь Postgres: "${LRED}$psql_user${NORMAL}
  echo -e "${BGBLACK}${LGREEN}Пароль Postgres: "${LRED}$psql_passwd${NORMAL}
  echo -e "${BGBLACK}${LGREEN}База Postgres: "${LRED}$psql_db${NORMAL}
  echo ""
}

install_userside(){
  cd $www_dir && php -r "copy('http://my.userside.eu/install', 'userside_install.phar');"
  cd $www_dir && php userside_install.phar
  chown -hR apache:apache $www_dir > /dev/null
}

install_all(){
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
  mkdir -p $www_dir/userside3 > /dev/null
	cat <<EOF > /etc/httpd/conf.d/userside.conf
<VirtualHost *:80>
   ServerAdmin $admin_email
   DocumentRoot "$www_dir/userside3"
   ServerName $domain
   ErrorLog "/var/log/httpd/userside-main-error.log"
   CustomLog "/var/log/httpd/userside-main-access.log" common
   <Directory "$www_dir/userside3">
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
  localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
  localectl set-locale LANG=ru_RU.UTF-8
  localectl set-keymap ru
  export LANG=ru_RU.UTF-8
}

set_timezone(){
  timedatectl set-timezone $time_zone
}

pre_settings_postgres(){
  sed -i '80s/peer/trust/' /var/lib/pgsql/10/data/pg_hba.conf
  sed -i '82,84s/ident/trust/' /var/lib/pgsql/10/data/pg_hba.conf
}

pre_settings_mysql(){
	cat <<EOF > /etc/my.cnf.d/charset.cnf
[client]
default-character-set=utf8

[mysql]
default-character-set=utf8

[mysqld]
character-set-server=utf8
init-connect='SET NAMES utf8'
collation-server=utf8_general_ci
EOF
}

post_settings_mysql(){
	cat <<EOF > /etc/my.cnf.d/timezone.cnf
[mysqld]
default-time-zone=$time_zone
EOF
  systemctl restart mysqld
}

settings_php(){
  sed -i "s|;date.timezone =|date.timezone =$time_zone|" /etc/php.ini
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
  mysql_tzinfo_to_sql /usr/share/zoneinfo > /tmp/zone_import.sql

/usr/bin/expect<<EOF
    log_user 0
    spawn mysql -uroot -p -e "CREATE DATABASE \`$mysql_db\` CHARACTER SET utf8 COLLATE utf8_general_ci; CREATE USER '$mysql_user'@'localhost' IDENTIFIED BY '$mysql_passwd'; GRANT ALL PRIVILEGES ON \`$mysql_db\` . * TO '$mysql_user'@'localhost'; FLUSH PRIVILEGES; use mysql; source /tmp/zone_import.sql;"
    expect "Enter password:"
    send "$mysql_root_passwd\n"
    expect eof
EOF
  rm /tmp/zone_import.sql
}

settings_crontab(){
  echo "* * * * *   www-data   php $www_dir/userside cron > /dev/null 2>&1"  >> /etc/crontab
}

LYELLOW='\033[1;33m'
LRED='\033[1;31m'
BGBLACK='\033[40m'
NORMAL='\033[0m'

echo -en "${BGBLACK}${LYELLOW}Подготовка скрипта. ${LRED} Ожидайте. "${NORMAL}

set_lang
install_utils &> /dev/null

www_dir="/var/www/userside"
domain="userside.example.com"
admin_email="admin@example.com"
time_zone="Europe/Moscow"
psql_user="userside"
psql_db="userside"
psql_passwd="ChangeMeNow"
mysql_root_passwd="ChangeMeNow"
mysql_passwd="ChangeMeNow"
mysql_user="userside"
mysql_db="userside"

exec 3>&1

dialog --ok-label "Сохранить" \
--backtitle "Установка Userside" \
--title "Настройки" \
--form "Введите все данные" \
20 90 0 \
"Директория установки сайта Userside:"	1 1	"$www_dir" 	1 45 25 0 \
"Домен сайта Userside:"			2 1	"$domain"  	2 45 25 0 \
"E-Mail администратора:"			3 1	"$admin_email" 	3 45 25 0 \
"Временная зона:"				4 1	"$time_zone" 	4 45 25 0 \
"Пользователь Postgres:"			5 1	"$psql_user" 	5 45 25 0 \
"База Postgres:"				6 1	"$psql_db" 	6 45 25 0 \
"Пароль Postgres:"				7 1	"$psql_passwd" 	7 45 25 0 \
"Пароль root-а MySQL:"			8 1	"$mysql_root_passwd" 	8 45 25 0 \
"Пользователь MySQL:"			9 1	"$mysql_user" 	9 45 25 0 \
"База MySQL:"				10 1	"$mysql_db" 	10 45 25 0 \
"Пароль пользователя MySQL:"		11 1	"$mysql_passwd" 	11 45 25 0 \
2>&1 1>&3 | {
  read -r www_dir
  read -r domain
  read -r admin_email
  read -r time_zone
  read -r psql_user
  read -r psql_db
  read -r psql_passwd
  read -r mysql_root_passwd
  read -r mysql_user
  read -r mysql_db
  read -r mysql_passwd

  LYELLOW='\033[1;33m'
  LRED='\033[1;31m'
  BGBLACK='\033[40m'
  NORMAL='\033[0m'

  if test $? -eq 0
  then

    echo -en "${BGBLACK}${LYELLOW}Выполняется установка и настройка компонентов. ${LRED} Ничего не зависло! Потерпите! "${NORMAL}

    set_timezone $time_zone
    install_all &> /dev/null
    enable_all &> /dev/null
    site_add $domain $admin_email $www_dir
    pre_settings_postgres
    pre_settings_mysql
    settings_php $time_zone
    run_all
    settings_postgres $psql_user $psql_passwd $psql_db
    settings_mysql $mysql_user $mysql_root_passwd $mysql_passwd $mysql_db
    settings_crontab $www_dir
    post_settings_mysql $time_zone > /dev/null
    echo_settings $www_dir $psql_user $psql_passwd $psql_db $mysql_user $mysql_passwd $mysql_db

  else
    echo -en "${BGBLACK}${LRED}Операция отменена"${NORMAL}
  fi

}

exec 3>&-

install_userside
