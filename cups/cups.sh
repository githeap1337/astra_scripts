#!/bin/bash

#############################################
### Настройка контроля печати Astra Linux ###
#############################################
# При печати в ненулевой сессии пользователь, после отправки документа на печать, 
# должен осуществить маркировку документа и регистрацию печати через web-интерфейс 
# КП Печати и маркировки документов (открыть в браузере /localhost/printcontrol.php), 
# отправить ожидающее печати задание на принтер, введя все необходимые данные о документе, 
# исполнителе, регистрации печати. После этого документ будет выведен на принтер.
# Настройка формата колонтитулов делается в утилите fly-admin-marker
# Журнал печати доступен в браузере /localhost/protocol.php

# Принцип работы
# Алгоритм штатной работы маркировки:
#     пользователь с любой рабочесй станции (в т.ч. той, к которой локально подключен принтер) посылает документ на печать из ненулевой сессии;
#     задание встает в очередь печати;
#     администратор печати (группа lpmac) видит задание в WEB интерфейсе printcontrol (доступен локально на станции печати или по сети);
#     администратор подтверждает печать и вводит дополнительные данные в жкрнал учета печати документов;
#     документ печатается.
# Также, если не установлен printcontrol, предусмотрен алгоритм отладки  маркировки с помощью консольной команды markjob:
#     пользователь посылает документ на печать из сессии с повышенными привелегиями;
#     задание встает в очередь печати, выводится сообщение с номером документа;
#     администратор печати (группа lpmac) выполняет команду markjob и указывает номер документа;
#     администратор вводит данные в ходе диалога, вызываемого markjob;
#     документ печатается.
# Перед настройкой службы печати должен быть настроен сервер Apache2 и подключен принтер.


# Установка web-сервера Apache


# Установка необходимых пакетов с диска ОС СН и подключение модулей Apache
apt-get install -y apache2 libapache2-mod-auth-pam libapache2-mod-php5 php5-cli php5-common
 
ldconfig
a2enmod php5
a2enmod auth_pam
Сервер Apache в Astra Linux не позволяет получать прямой доступ (без авторизации) к развернутым web-ресурсам, поэтому для его работы должен быть соответствующим образом настроен PAM.

# Создание резервной копии
cp /etc/pam.d/apache2 /var/backups/apache2.`date +%s`
 
# Настройка PAM
cat > /etc/pam.d/apache2<<EOF
# Default
# @include common-auth
# @include common-account
auth    required                        pam_tally2.so        onerr=succeed file=/var/log/faillog
auth    [success=1 default=ignore]      pam_unix.so          nullok_secure try_first_pass
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so
@include common-account
EOF
 
# Назначить права пользователю www-data (для корректной работы PAM)
setfacl -m u:www-data:rw /var/log/faillog
 
# Настроить конфигурационный файл apache2.conf
sed -i -e '/^ServerName/d' /etc/apache2/apache2.conf
echo "ServerName localhost" >>/etc/apache2/apache2.conf
 
# Настроить конфигурационный файл php.ini
sed -i -e 's/[;[:space:]\t]date.timezone[=[:space:]].*/date.timezone = "Europe\/Moscow"/g' /etc/php5/apache2/php.ini
sed -i -e 's/[;[:space:]\t]date.timezone[=[:space:]].*/date.timezone = "Europe\/Moscow"/g' /etc/php5/cli/php.ini
 
# Удаляем стандартные виртуальные хосты
rm /etc/apache2/sites-enabled/*
rm /etc/apache2/sites-available/*
 
# Выполняем перезагрузку службы
chkconfig apache2 on
service apache2 restart

# Сверяем файл (default состояние)
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
    Listen 443
</IfModule>
 
<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
EOF

# Права доступа Apache к информации о метках и категориях
# Выставить необходимые права доступа пользователю www-data
usermod -a -G shadow www-data
setfacl -d -m u:www-data:r  /etc/parsec/macdb
setfacl -R -m u:www-data:r  /etc/parsec/macdb
setfacl -m    u:www-data:rx /etc/parsec/macdb
setfacl -d -m u:www-data:r  /etc/parsec/capdb
setfacl -R -m u:www-data:r  /etc/parsec/capdb
setfacl -m    u:www-data:rx /etc/parsec/capdb
 
# Выполняем перезагрузку службы
service apache2 restart


# Настройка КП Печати и маркировки документов
# Перед настройкой службы печати должен быть настроен принтер и сервер Apache2

# Настройка прав пользователей
# В системе изначально есть группы lp - права печатать, lpadmin - администратор печати.

# необходимо добавить группу администора маркировки документов
groupadd -g 900 lpmac
 
# включить пользователей в группы
usermod -a -G lpadmin,lp,lpmac root
usermod -a -G lpadmin,lp,lpmac Admin
usermod -a -G lp user

# Настройка службы CUPS
# Настройка производится для корректной работы подсистемы печати с пакетом printcontrol и МРД

cupsctl --remote-admin --remote-printers --remote-any
cupsctl ServerAlias=*
cupsctl DefaultAuthType=Basic
sudo cupsctl MarkerUser=ipp
sudo cupsctl MacEnable=ON
sudo cupsctl DefaulPolicy=parsec
 
service cups stop
service cups start
Настройка колонтитулов
# настроить формат колонтитулов
fly-admin-marker
# /usr/share/cups/marker.template
# /usr/share/cups/marker.defs
# /usr/share/cups/fonarik.defs

# Настройки сгенерированы утилитой fly-admin-marker

/usr/share/cups/marker.template
    fonarik_border=5
    first:normal:12:Arial:top-right:{LEVEL_NAME}
    first:normal:12:Arial:top-right:Экз.N{CURRENT_COPY}
    first:normal:10:Verdana:bottom-right:
    first:normal:12:Arial:bottom-right:{mac-inv-num}
    last:normal:12:Arial:top-right:{LEVEL_NAME}
    last:normal:12:Arial:bottom-right:{mac-inv-num}
    any:normal:12:Arial:top-right:{LEVEL_NAME}
    any:normal:12:Arial:bottom-right:{mac-inv-num}
    fonarik:normal:12:Arial:top-left:{mac-inv-num}
    fonarik:normal:12:Arial:top-left:Экземпляров {copies}
    fonarik:normal:12:Arial:top-left:{mac-workplace-id}
    fonarik:normal:12:Arial:top-left:[mac-distribution]
    fonarik:normal:12:Arial:top-left:Исполнитель {JOB_OWNER}
    fonarik:normal:12:Arial:top-left:Тел. {mac-owner-phone}
    fonarik:normal:12:Arial:top-left:Отпечатал {PRINT_USER_NAME}
    fonarik:normal:12:Arial:top-left:{DATE}
    fonarik_gt_5:normal:12:Arial:top-left:Исполнитель {JOB_OWNER}
    fonarik_gt_5:normal:12:Arial:top-left:Тел. {mac-owner-phone}

# Настройки отступов всех страниц

/usr/share/cups/psmarker/marker.defs 
    MarkerTopShift=20.0
    MarkerBottomShift=20.0
    MarkerLeftShift=36.0
    MarkerRightShift=36.0
    MarkerStringInterval=4.0

# Настройки отступов фонарика

/usr/share/cups/fonarik/fonarik.defs
    FonarikTopShift=520.0
    FonarikBottomShift=20.0
    FonarikLeftShift=36.0
    FonarikRightShift=36.0
    FonarikStringInterval=4.0


# Установка WEB-интерфейса printcontrol

# Устанавниваем пакет

apt-get install printcontrol-web firefox

# Настраиваем сайт
# добавляем конфиг сайта с авторизацией через pam
cat > /etc/apache2/sites-available/printcontrol<<EOF
 
<VirtualHost *:80>
    ServerAdmin root@localhost
    ServerName printcontrol
    ServerAlias www.printcontrol.local
    DocumentRoot /var/www/printcontrol/prog
    <Directory /var/www/printcontrol/prog>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride None
#       DirectoryIndex UnitList.php
        AuthPAM_Enabled on
        AuthType Basic
        AuthName "Please login"
        AuthPAM_FallThrough off
        AuthBasicAuthoritative off
        require valid-user
    </Directory>
 #  ErrorLog /var/log/apache2/error.log
    ErrorLog /var/log/apache2/printcontrol-error.log
    LogLevel warn
#   CustomLog /var/log/apache2/access.log combined
    CustomLog /var/log/apache2/printcontrol-access.log combined
</VirtualHost>
EOF

# выставляем права
chown www-data:lpmac /var/www/printcontrol/
chmod -R 570 /var/www/printcontrol/
 
# выставляем дискреционные права пользователю на файлы сайта
setfacl -R -m u:www-data:rx /var/www/printcontrol/
setfacl -dR -m u:www-data:rx /var/www/printcontrol/
 
# добавляем адрес сервера в /etc/hosts
echo -e '127.0.0.1  printcontrol.local' >> /etc/hosts
 
# запускаем сайт
a2ensite printcontrol
/etc/init.d/apache2 restart
 
# войти на сайт по адресу http://localhost/printcontrol.php
# WEB-интерфейс будет доступен по адресу printcontrol.local/printcontrol.php

# Создание ярлыка для запуска с рабочего стола
# Создаем ярлык "HTTP Управление печатью документов"

cat > /usr/share/fly-dm/sessions/princtontrol.desktop<<EOF
[Desktop Entry]
Encoding=UTF-8
Name=Printcontrol
Name[ru]=Управление печатью документов
Type=Application
Exec=firefox printcontrol.local/printcontrol.php
Icon=print_class
Terminal=false
EOF
  
# Копируем ярлык на рабочий стол пользователя Admin
cp /usr/share/fly-dm/sessions/princtontrol.desktop /home/Admin/Desktop/
# Для будущих пользователей, если надо (обычно не надо - только админу)
# cp /usr/share/fly-dm/sessions/princtontrol.desktop /usr/share/fly-wm/Desktops/


# Финальная настройка
# После настройки системы печати необходимо определить на каких уровнях привелегий будет возможна печать документов.
# после настройки принтера выставить права возможности / невозможности печати из под мандатных меток
sudo lpadmin -p OKI_DATA_CORP_B4600 -o printer-op-policy=parsec
sudo lpadmin -p OKI_DATA_CORP_B4600 -o mon-printer-mac-max=2:0
sudo lpadmin -p OKI_DATA_CORP_B4600 -o mon-printer-mac-min=0:0
 
service cups stop
service cups start


# Дополнительно
# Вариант работы без pam

# Вариант из руководства админа без pam - вроде не работает
cat > /etc/apache2/sites-available/printcontrol<<EOF                                                                                                                                                                
<VirtualHost *:80>
    ServerAdmin root@localhost
    ServerName printcontrol
    DocumentRoot /var/www/printcontrol/prog
        <Directory /var/www/printcontrol/prog>
            Options Indexes FollowSymLinks MultiViews
            AllowOverride None
        </Directory>
    ErrorLog /var/log/apache2/error.log
    LogLevel warn
    CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF

# Работа системы маркировки документов только из мандатной сессии
# выставляем мандатные атрибуты веб-админке системы печати (будет доступна под меткой 2)
# pdp-flbl -Rv 0:0:0:ccnr /var/www
# chmac -Rv 2:0 /var/www/printcontrol/