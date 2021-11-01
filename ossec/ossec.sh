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

# Скрываем системных пользователей в окне авторизации Astra Linux
sed -i -e '/^HiddenUsers/s/=.*/=root,fly-dm,ossec,ossecm,ossecr,bacula,modisa,paramreg/g' /etc/X11/fly-dm/fly-dmrc
 
# Перезагружаем службу декстоп менеджера fly-dm
# systemctl restart fly-dm
service fly-dm restart

#######################################################
############### Настройка сервера ossec ###############
####################################################### 

# Создаем резервные копии файлов
cp /var/ossec/etc/10-ossec-syslog.conf /var/backups/10-ossec-syslog.conf."$DATE"
cp /var/ossec/bin/ossec_audit_send.sh /var/backups/ossec_audit_send.sh."$DATE"
cp /var/ossec/etc/ossec.conf /var/backups/ossec.conf."$DATE"
cp /var/ossec/etc/decoder.xml /var/backups/decoder.xml."$DATE"
cp /var/ossec/rules/admin.xml /var/backups/admin.xml."$DATE"
cp /var/ossec/rules/auth.xml /var/backups/auth.xml."$DATE"
cp /var/ossec/rules/afick.xml /var/backups/afick.xml."$DATE"
cp /var/ossec/rules/parsec.xml /var/backups/parsec.xml."$DATE"

# Изменяем конфигурационный файл 10-ossec-syslog.conf
sed -i -e '/#$template/s/#//g' /var/ossec/etc/10-ossec-syslog.conf
sed -i -e '/#auth/s/#//g' /var/ossec/etc/10-ossec-syslog.conf
sed -i -e '/#user/s/#//g' /var/ossec/etc/10-ossec-syslog.conf
 
# Изменяем скрипт ossec_audit_send.sh по сбору логов
sed -i -e '/parselog/s/#all.*//g' /var/ossec/bin/ossec_audit_send.sh
 
# Изменяем конфигурационный файл login.defs
sed -i -e '/FAILLOG_ENAB/s/.*/FAILLOG_ENAB no/g' /etc/login.defs
 
# Изменяем конфигурационный файл ossec.conf
sed -i -e 's/report_changes="yes" //g; s/realtime="yes" //g' /var/ossec/etc/ossec.conf
sed -i -e 's/<directories /&report_changes="yes" realtime="yes" /' /var/ossec/etc/ossec.conf

# Проверяем содержание строки в файле ossec.conf
# должно быть <white_list>127.0.0.1</white_list>
grep white_list /var/ossec/etc/ossec.conf


# TODO: Перенести в скрипт sed -i -e
# Убрать символы комментария <!-- на следующих блоках в файле /var/ossec/etc/ossec.conf
# <localfile>
# <log_format>command</log_format>
# <command>/var/ossec/bin/check_running_audit_send.sh</command>
# </localfile>
# <localfile>
# <log_format>command</log_format>
# <command>/var/ossec/bin/parseclog.sh</command>
# </localfile>

# Создаем необходимые ссылки
ln -sf /var/ossec/bin/ossec-logtest /var/ossec/ossec-logtest
ln -sf /var/ossec/etc/10-ossec-syslog.conf /etc/rsyslog.d/

# Добавляем пользователя admin в группу ossec
ADMIN=admin
usermod -a -G ossec ${ADMIN}
 
# Добавляем пользователю admin необходимые права 
setfacl -m    u:${ADMIN}:rw  /var/log/faillog
setfacl -R -m u:${ADMIN}:rwx /var/www/ossec/
setfacl -m    u:${ADMIN}:rx  /var/ossec/
setfacl -m    u:${ADMIN}:rx  /var/ossec/bin/
setfacl -m    u:${ADMIN}:rx  /var/ossec/bin/manage_agents
setfacl -m    u:${ADMIN}:rx  /var/ossec/bin/agent_control
setfacl -R -m u:${ADMIN}:rx  /var/ossec/rules/
 
# Добавляем пользователю www-data необходимые права  
setfacl -R -m  u:www-data:rx /var/www/ossec/
setfacl -dR -m u:www-data:rx /var/www/ossec/
 
# Перезапускаем  службы
# systemctl restart rsyslog
# systemctl restart ossec-hids-server
# systemctl restart apache2
# systemctl restart cron
# systemctl restart incron
service rsyslog restart
service ossec-hids-server restart
service apache2 restart
service cron restart
service incron restart

#######################################################
################ Настройка службы cron ################
####################################################### 

# Создадим файл /etc/cron.d/incron
echo '*/1 * * * * root [ -x /etc/cron.daily/incron_service ] && /etc/cron.daily/incron_service' >/etc/cron.d/incron
 
# Создадим файл /etc/cron.daily/incron_service
echo -e '#!/bin/bash\n/etc/init.d/incron restart' >/etc/cron.daily/incron_service
 
# Добавляем необходимые права доступа на файлы
chmod 755 /etc/cron.daily/incron_service
chmod 755 /etc/cron.d/incron
 
# Изменим расписание запуска afick для получения актуальной информации по контролю целостности
cat > /etc/cron.d/afick<<EOF
#
# Regular cron jobs for the afick package
#
#0 4    * * *   root    [ -x /etc/cron.daily/afick_cron ] && /etc/cron.daily/afick_cron
0 */5 * * *   root    [ -x /etc/cron.daily/afick_cron ] && /etc/cron.daily/afick_cron
EOF
 
# Перезапустить службу
#systemctl restart cron
service cron restart

#######################################################
##### Исправление ошибок работы ossec-hids-server #####
#######################################################

# TODO: проверить скрипт от внедрения

# Вносим правку в работу демона "ossec-hids-server", в связи с некорректным запуском:
# не всегда стартует модуль после перезагрузки АРМ
# не отображаются логи в браузере
# удаляем пустые логи в папке /var/www/ossec/data/, которые создаются при некорректном завершении работы

sed -i -e '/find/d; /sleep/d; /logcollector/d;' /etc/init.d/ossec-hids-server
sed -i -e '/start()/a \\tfind \/var\/www\/ossec\/data\/ -name "*.log" -type f -empty -exec rm {} \\;' /etc/init.d/ossec-hids-server
sed -i -e '/control start/a \\tsleep 5\n\t\/var\/ossec\/bin\/ossec-logcollector' /etc/init.d/ossec-hids-server

Если при использовании ALD, появляются ошибки в лог файле archives.log: 
# grep error /var/ossec/logs/archives/archives.log
#     [error] [client 127.0.0.1] PHP Notice:  Undefined index: KRB5CCNAME in /var/www/ossec/prog/UnitList.php on line 2

sed -i -e '/^putenv.*KRB5CCNAME=/s/.*/# &/g' /var/www/ossec/prog/UnitList.php

# В случае аварийной остановки службы ossec-web при накоплении больших логов, 
# увеличиваем количество выделяемой памяти и времени выполнения скрипта.
# Изменяем скрипт UnitList.php по чтению логов
sed -i -e '/memory_limit/d; /max_execution_time/d' /var/www/ossec/prog/UnitList.php
sed -i -e "/<?php.*/aini_set('max_execution_time', '60');" /var/www/ossec/prog/UnitList.php
sed -i -e "/<?php.*/aini_set('memory_limit', '512M');" /var/www/ossec/prog/UnitList.php

#######################################################
################# Настройка wui ossec #################
####################################################### 

# Создаем конфигурационный файл ossec
cat > /etc/apache2/sites-available/ossec<<EOF
<VirtualHost *:80>
    ServerAdmin root@localhost
    ServerName ossec.local
    ServerAlias www.ossec.local
    ServerAlias ossec
    DocumentRoot /var/www/ossec/prog
    <Directory /var/www/ossec/prog>
        Options FollowSymLinks
        AllowOverride None
        DirectoryIndex UnitList.php
        AuthPAM_Enabled on
        AuthType Basic
        AuthName "Please login"
        AuthPAM_FallThrough off
        AuthBasicAuthoritative off
        require valid-user
    </Directory>
    #ErrorLog ${APACHE_LOG_DIR}/error.log
    #LogLevel info
    #CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
 
# Создаем символическую ссылку
ln -sf /etc/apache2/sites-available/ossec /etc/apache2/sites-enabled/000-ossec
 
# Перезапустить службу
# systemctl restart apache2
service apache2 restart

#######################################################
########### Настройка звуковой сигнализации ###########
#######################################################

# TODO: проверить скрипт от внедрения

# Устанавливаем пакеты для отображения 
apt-get install -y notification-daemon libnotify-bin
 
# Изменяем конфигурационный файл Xsetup (разрешаем отображать сообщения на мониторе)
sed -i -e "/^xhost.*/d" /etc/X11/fly-dm/Xsetup
echo "xhost +local:root" >>/etc/X11/fly-dm/Xsetup
 
# Перезапускаем службу 
service fly-dm restart

# Проверяем наличие файла
ls -la /usr/share/fly-wm/sounds/x-fly-wm-ring.wav
 
# Создаем файл notify-send.sh по отображению и звуковому оповещению о событиях
cat > /var/ossec/active-response/bin/notify-send.sh<<EOF
#!/bin/sh
(flock -n 9 || exit 1
export DISPLAY=:0
level=`tail -n5 /var/ossec/logs/alerts/$(date +"%Y")/$(LC_ALL=en_AU.UTF-8 date +"%h")/ossec-alerts-$(date +"%d").log | grep -o "(level[^)]*)" | grep -o "[0-9]*"`
if [ "$level" -gt 3 ] && [ "$level" -lt 10 ]; then
    notify-send "Сообщение события безопасности информации:" -u normal -t 5000 "<font size=4>Произошло важное событие! Обратитесь к администратору по обеспечению безопасности информации!</font>"
    for n in {1..15}; do aplay -q /usr/share/fly-wm/sounds/x-fly-wm-ring.wav; done
elif [ "$level" -ge 10 ]; then
    notify-send "Сообщение события безопасности информации:" -u critical -t 5000 "<font size=4>Произошло критическое событие! Обратитесь к администратору по обеспечению безопасности информации!</font>"
    for n in {1..15}; do aplay -q /usr/share/fly-wm/sounds/x-fly-wm-ring.wav; done
else :
fi
) 9>/var/lock/notify-send
EOF
 
# Выставляем необходимые права доступа на файл
chmod +x /var/ossec/active-response/bin/notify-send.sh
 
# Изменяем конфигурационный файл /var/ossec/etc/ossec.conf (добавляем новый блок)
cat > /var/ossec/etc/ossec.conf<<EOF
 <command>
    <name>notify-send</name>
    <executable>notify-send.sh</executable>
    <expect></expect>
  </command>
EOF

sed -i -e '/<active-response>/,/<\/active-response>/d' /var/ossec/etc/ossec.conf
sed -i -e '/Active Response Config/a \<active-response>\n<command>notify-send<\/command>\n<location>local<\/location>\n<level>1<\/level>\n<\/active-response>' /var/ossec/etc/ossec.conf

#######################################################
########## Запуск ossec, проверка его работы ##########
#######################################################

# Перезапускаем службы
service rsyslog restart
service ossec-hids-server restart
service apache2 restart
service cron restart
service incron restart
 
# Проверяем выводом 50 строк list agent
# /var/ossec/bin/agent_control -lc
#     OSSEC HIDS agent_control. List of available agents:
#     ID: 000, Name: arm1 (server), IP: 127.0.0.1, Active/Local
# /var/ossec/bin/agent_control -i 000
#     Status:     Active/Local
# /var/ossec/bin/agent_control -r -u 000
#     OSSEC HIDS agent_control: Restarting Syscheck/Rootcheck locally.
 
# Это нормально, так как работаем только локально, только сервер без агентов.
# /var/ossec/bin/verify-agent-conf
#     2020/12/25 12:40:11 ossec-config(1226): ERROR: Error reading XML file '/var/ossec/etc/shared/agent.conf': XMLERR: File...
 
# view log ossec
tail -50 /var/ossec/logs/ossec.log
 
# view log ossec web
tail -f /var/ossec/logs/alerts/alerts.log

# Остановить службы
service ossec-hids-server stop
service apache2 stop
 
#######################################################
################ Удаление логов ossec #################
#######################################################

# Удаляем логи
[ -d /var/ossec/logs ] && find /var/ossec/logs -type f -exec bash -c 'for item do > $item; done' bash {} +
[ -d /var/ossec/stats ] && find /var/ossec/stats -type f -exec bash -c 'for item do > $item; done' bash {} +
[ -d /var/remote_logs ] && rm -rf /var/remote_logs/*
[ -d /var/www/ossec/data ] && rm -rf /var/www/ossec/data/*
[ -f /var/ossec/etc/lasttime ] && >/var/ossec/etc/lasttime
[ -f /var/ossec/etc/lasttime ] && >/var/ossec/etc/lasttimefile
find /var/log -type f -exec bash -c 'for item do > $item; done' bash {} +
 
# Перезапускаем службы
service rsyslog restart
service ossec-hids-server restart
service apache2 restart
service incron restart

# Перезагрузка 
# reboot