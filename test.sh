#!/bin/bash
#
# Скрипт для тестов
#

install_utils(){
	rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 > /dev/null
	yum -y -q install expect dialog wget sudo > /dev/null
    echo "one"
}

install_epel(){
	yum -y -q install epel-release &> /dev/null
	rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 > /dev/null
    echo "two"
}

install_webtatic(){
	yum -y -q install https://mirror.webtatic.com/yum/el7/webtatic-release.rpm > /dev/null
	rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-webtatic-el7 > /dev/null
    echo "three"
}

install_php7_apache(){
	yum install -y -q php71w mod_php71w php71w-cli php71w-common php71w-gd php71w-mbstring php71w-mcrypt php71w-mysqlnd php71w-xml php71w-intl php71w-pdo php71w-snmp php71w-xml php71w-soap php71w-pgsql > /dev/null
	echo "four"
}

install_utils
install_epel
install_webtatic
install_php7_apache
