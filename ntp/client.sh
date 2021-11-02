#!/bin/bash

# Выполняется на ntp-клиенте

# Установить ntp
apt-get install ntp ntpdate -y
 
# Настройка временной зоны 
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
 
# Бэкап файла конифгурации 
# cp /etc/ntp.conf /etc/ntp.conf.`date +%s`
cp /etc/ntp.conf /var/backups/ntp.conf.`date +%s`
 
# Настраиваем ntp, добавляя ip-адрес своего сервера и в ip-адрес сети в restrict 
cat > /etc/ntp.conf <<EOF
# Используемые общедоступные сервера пулов NTP
server 192.168.10.1 iburst prefer
# Доступ на чтение только в local net
interface ignore wildcard
interface listen 127.0.0.1
restrict default ignore
restrict 192.168.10.0 mask 255.255.255.0 nomodify notrap
restrict 127.0.0.1
# Месторасположение файлов drift и log
driftfile /var/lib/ntp/ntp.drift
logfile /var/log/ntp.log
disable monitor
EOF

# Вносим дополнительные параметры для запуска ntp 
sed -i -e "/NTPDATE_USE_NTP_CONF/s/=.*/=yes/g" /etc/default/ntpdate
sed -i -e "/NTPSERVERS/s/=.*/=\"\"/g" /etc/default/ntpdate
sed -i -e "/NTPOPTIONS/s/=.*/=\"\"/g" /etc/default/ntpdate
sed -i -e 's|/home/ntp:|/nonexistent:|g' /etc/passwd
 
# Добавляем ntp в автозагрузку и перезапускаем 
chkconfig ntp on
service ntp restart
 
# Подождать ~5 минут и продолжить выполнять команды
sleep 5m

# Обновим показания времени, ip-адрес сервера времени указываем свой
ntpdate -u 192.168.10.1

# Удаляем файл коррекции времени 
rm -rf /etc/adjtime

# Настраиваем аппаратные часы 
hwclock --systohc
hwclock --adjust
hwclock --systohc --utc
