#!/bin/bash

# Bash срипт для настройки ossec на Astra Linux
# Выполнять с правами суперпользователя

# ossec-hids-server - серверный пакет
# ossec-hids-agent - клиентский пакет 
# ossec-web - wui графический интерфейс
# ossec-cnt - настройка бездисковых станций


#######################################################
######## Установка и настройка Apache2 для wui ######## 
#######################################################

# Устанавливаем необходимые пакеты

apt-get install -y apache2 libapache2-mod-auth-pam libapache2-mod-php5 php5-cli php5-common

# Проверяем библиотеки 
ldconfig

# Подключаем модули к Apache2
a2enmod php5
a2enmod auth_pam 

# Настраиваем PAM, чтобы получать прямой доступ (без авторизации) к развернутым web-ресурсам

# Переменные
DATE=$(date +"%d-%m-%Y")
HOSTNAME=$(hostname)

# Создаем резервную копию PAM для Apache2
cp /etc/pam.d/apache2 /var/backups/apache2."$DATE"

# Настраиваем PAM
cat > /etc/pam.d/apache2<<EOF
auth    required                        pam_tally2.so        onerr=succeed file=/var/log/faillog
auth    [success=1 default=ignore]      pam_unix.so          nullok_secure try_first_pass
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so
@include common-account
EOF

# Назначаем права пользователю www-data
setfacl -m u:www-data:rw /var/log/faillog

# Заменяем имя сервера на locslhost в apache2.conf
sed -i -e '/^ServerName/d' /etc/apache2/apache2.conf
echo "ServerName localhost" >>/etc/apache2/apache2.conf

# Настраиваем таймзону в конфигурационном файле php.ini
sed -i -e 's/[;[:space:]\t]date.timezone[=[:space:]].*/date.timezone = "Europe\/Moscow"/g' /etc/php5/apache2/php.ini
sed -i -e 's/[;[:space:]\t]date.timezone[=[:space:]].*/date.timezone = "Europe\/Moscow"/g' /etc/php5/cli/php.ini

# Удаляем стандартные виртуальные хосты
rm /etc/apache2/sites-enabled/*
rm /etc/apache2/sites-available/*
 
# Добавляем apache2 в автозапуск и перезапускаем службы
# update-rc.d apache2 defaults
# systemctl restart apache2
chkconfig apache2 on
service apache2 restart

# Сверяем файл c доступными портами
 
cat > /etc/apache2/ports.conf<<EOF
# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default
# This is also true if you have upgraded from before 2.2.9-3 (i.e. from
# Debian etch). See /usr/share/doc/apache2.2-common/NEWS.Debian.gz and
# README.Debian.gz
 
NameVirtualHost *:80
Listen 80
 
<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/apache2/sites-available/default-ssl
    # to <VirtualHost *:443>
    # Server Name Indication for SSL named virtual hosts is currently not
    # supported by MSIE on Windows XP.
    # NameVirtualHost *:443
    Listen 443
</IfModule>
 
<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
EOF

# Добавляем пользователя www-data в группу shadow
usermod -a -G shadow www-data

# Устанавливаем необходимые права для пользователя www-data
setfacl -d -m u:www-data:r  /etc/parsec/macdb
setfacl -R -m u:www-data:r  /etc/parsec/macdb
setfacl -m    u:www-data:rx /etc/parsec/macdb
setfacl -d -m u:www-data:r  /etc/parsec/capdb
setfacl -R -m u:www-data:r  /etc/parsec/capdb
setfacl -m    u:www-data:rx /etc/parsec/capdb
 
# Выполняем перезагрузку службы
# systemctl restart apache2
service apache2 restart

#######################################################
############### Установка сервера ossec ############### 
#######################################################

# Удаляем ранее установленные пакеты (при наличии)
apt-get purge -y ossec-hids-server ossec-web
userdel ossec
userdel ossecm
userdel ossecr

# Создаем системную группу и пользователей для работы системы центрального протоколирования ossec, а также основной каталог ossec
groupadd -g 998 ossec
mkdir -p /var/ossec
adduser --system --home /var/ossec --shell /sbin/nologin --no-create-home --uid 991 --ingroup ossec --disabled-password --gecos "ossec" ossec
adduser --system --home /var/ossec --shell /sbin/nologin --no-create-home --uid 992 --ingroup ossec --disabled-password --gecos "ossec-monitord" ossecm
adduser --system --home /var/ossec --shell /sbin/nologin --no-create-home --uid 993 --ingroup ossec --disabled-password --gecos "ossec-remoted" ossecr
chown root:ossec /var/ossec
chmod 770 /var/ossec

# Установка необходимых пакетов и браузера
apt-get install -y ossec-hids-server ossec-web incron firefox
 
# Включаем службу parlogd в автозагрузку
# update-rc.d parlogd defaults
chkconfig parlogd on
 
# Добавляем имя компьютера в конфигурационный файл /etc/hosts
# ! Не допускать лишних пробелов
cat > /etc/hosts<<EOF
127.0.0.1 "$HOSTNAME" ossec.local localhost
EOF
 
# Сверяем имя компьютера в разных конфигурационных файлов /etc/hostname и /etc/hosts (должно быть одинаковым). Имя АРМ будет выводиться в ossec-web.
cat /etc/hostname
grep 127.0.0.1 /etc/hosts

# Скрываем системных пользователей в окне авторизации ОС СН
sed -i -e '/^HiddenUsers/s/=.*/=root,fly-dm,ossec,ossecm,ossecr,bacula,modisa,paramreg/g' /etc/X11/fly-dm/fly-dmrc
 
# Перезагружаем службу декстоп менеджера fly-dm
# systemctl restart fly-dm
service fly-dm restart