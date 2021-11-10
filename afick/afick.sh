#!/bin/bash

#########################################
### Контроль целостности файлов afick ###
#########################################

# Создать службу afickd и поместить в автозапуск

cat > /etc/init.d/afickd<<EOF
#! /bin/sh
### BEGIN INIT INFO
# Provides:          afickd
# Required-Start:    $local_fs $remote_fs
# Required-Stop:
# Should-Start:
# Default-Start:     S
# Default-Stop:
# Short-Description:
# Description:       Checking checksums of protected files
### END INIT INFO
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LINE=30
if [ -f /lib/lsb/init-functions ]; then
    . /lib/lsb/init-functions
else
    log_action_begin_msg () {
        echo -n "$@... "
    }
  
    log_action_end_msg () {
        if [ "$1" -eq 0 ]; then
            echo done.
        else
            echo failed.
        fi
    }
fi
function pause(){
   read -p "$*"
}
case "$1" in
  start)
    setupcon --save &>/dev/null;
    log_action_msg "afick: File integrity check in progress ...."
    run=`afick -k -c /etc/afick.conf -D /var/local/afick/md5.db`
    if [ $? -gt 0 ]; then
        list=`afick_archive.pl --search "file|directory"`      
        log_action_msg "afick: Displayed $LINE strings"
        echo "$list" | tail -n $LINE
        log_action_begin_msg "afick: Integrity of the controlled data is violated"      
        log_action_end_msg 1
        pause 'Press [Enter] to continue booting the OS'
    else
        log_action_begin_msg "afick: The integrity check completed successfully (`date`)"
        log_action_end_msg 0
    fi
    ;;
  *)
   echo 'Usage: /etc/init.d/afickd {start}'
   exit 1
   ;;
esac
exit 0
EOF
 
# Выдать необходимые права и добавить в автозагрузку службы afickd
chown root:root /etc/init.d/afickd
chmod 755 /etc/init.d/afickd
chkconfig afickd on


# То, что выше видимо LEGACY скрипт (либо для старых версий ос), оставлю на всякий случай
# Установить с диска ОС СН необходимые пакеты
apt-get install -y afick gostsum
 
# Создать ярлык
# Terminal=true - команда su заблокирована
cat > /usr/share/applications/afick.desktop<<EOF
[Desktop Entry]
Name=another file integrity checker
Name[fr]=afick
Name[ru]=Контроль целостности файлов
Comment=a quick and portable tripwire's clone
Comment[ru]=Контроль целостности файлов
Exec=/usr/bin/fly-su -- /usr/bin/afick-tk
Terminal=false
Type=Application
Icon=/usr/share/pixmaps/afick.png
Categories=Application;System;
EOF
 
# Скопировать ярлык на рабочий стол администратора
chmod 640 /usr/share/applications/afick.desktop
chgrp astra-admin /usr/share/applications/afick.desktop
\cp -afx /usr/share/applications/afick.desktop /usr/share/fly-wm/Desktops/Desktop1/.
find /home -maxdepth 1 -type d -name "[aA]dmin" -exec cp -axf /usr/share/fly-wm/Desktops/Desktop1/afick.desktop {}/Desktops/Desktop1/. \;
 
# Проверить наличие файлов
ls -la /etc/cron.d/afick /etc/cron.daily/afick_cron
 
# Выставить необходимые права доступа
chmod 755 /etc/cron.d/afick /etc/cron.daily/afick_cron
 
# Изменить скрипт запуска службы afick (добавляем переменную "MDBFILE" и корректируем строку "nice -n $NICE $AFICK")
sed -i -e '/^MDBFILE/d' /etc/cron.daily/afick_cron
sed -i -e '/^CONFFILE/a\MDBFILE="/var/local/afick/md5.db"' /etc/cron.daily/afick_cron
sed -i -e 's/^nice/# &/' /etc/cron.daily/afick_cron
sed -i -e '/^# launch command/a\nice -n $NICE $AFICK -k -c $CONFFILE -D $MDBFILE > $LOGFILE 2>$ERRORLOG' /etc/cron.daily/afick_cron
 
# Создаем директорию для хранения эталонных значений контрольных сумм и атрибутов файлов
mkdir -p /var/local/afick/
cp /etc/afick.conf /etc/afick_full.conf
 
# Настраиваем конфигурационный файл afick.conf (для проверки целостности при загрузке ОС СН)
sed -i -e '/^database[:=]/s/[:=].*/ := \/var\/local\/afick\/md5.db/' /etc/afick.conf
sed -i -e '/^report_syslog/s/no/yes/' /etc/afick.conf
sed -i -e '/fstab/d; /udev/d' /etc/afick.conf
cat >> /etc/afick.conf<<EOF
/etc/fstab ETC
/etc/udev/rules.d ETC
EOF
 
# Настраиваем конфигурационный файл afick_full.conf (для проверки целостности файлов в ручном режиме)
sed -i -e '/^report_syslog/s/yes/no/' /etc/afick_full.conf
sed -i -e '/seaproject/d; /^\/root /d; /^\/usr /d; /^\/lib /d; /^\/lib64 /d; /^\/var\//d;' /etc/afick_full.conf
cat >> /etc/afick_full.conf<<EOF
/opt/seaproject GOST
/lib GOST
/lib64 GOST
/var/www GOST
/var/lib GOST
/root GOST
/usr GOST
EOF
 
# Очистить архивные записи
rm -f /var/log/afick/*
rm -f /var/lib/afick/archive/*
> /var/lib/afick/history
 
# Создаем БД по хранению значений: полный путь к файлам, контрольные суммы и атрибутов файлов
afick -i -c /etc/afick.conf -D /var/local/afick/md5.db
afick -i -c /etc/afick_full.conf -D /var/local/afick/md5_full.db
 
# Администратору необходимо записать полученные файлы на CD-диск
- /etc/afick_full.conf
- /var/lib/afick/md5_full.db
 
# Запускать раз в месяц для полной проверки. Вставить CD-диск c md5_full.db и запустить команду:
afick -k -c /media/cdrom0/afick_full.conf -D /media/cdrom0/md5_full.db
 
# Обновить БД при изменений контролируемых файлов
afick -u -c /etc/afick.conf -D /var/local/afick/md5.db