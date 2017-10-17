#!/bin/bash
#
# Скрипт для тестов
#

install_utils(){
	yum -y -q install expect dialog wget sudo
    echo "one"
}

install_epel(){
	yum -y -q install epel-release
    echo "two"
}

install_webtatic(){
	yum -y -q install https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
    echo "three"
}

install_php7_apache(){
	yum install -y -q php71w mod_php71w php71w-cli php71w-common php71w-gd php71w-mbstring php71w-mcrypt php71w-mysqlnd php71w-xml php71w-intl php71w-pdo php71w-snmp php71w-xml php71w-soap php71w-pgsql
	echo "four"
}

install_utils
install_epel
install_webtatic
install_php7_apache &> /dev/null
