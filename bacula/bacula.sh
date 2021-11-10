#!/bin/bash

#########################################################
### Резервное копирование данных - bacula Astra Linux ###
#########################################################

# Настройка резервного копирования

# Подготовка.
# Пользователь "admin" должен быть в ОС
# Удалить ранее установленные пакеты
apt-get purge -y bacula-server
 
# Создать системную группу и пользователя для работы программы резервного копирования
groupadd -g 903 bacula
mkdir -p /var/lib/bacula
adduser --system --home /var/lib/bacula --shell /sbin/nologin --no-create-home --uid 995 --gecos "bacula" --ingroup bacula --disabled-password bacula
chown root:bacula /var/lib/bacula
chmod 770 /var/lib/bacula
 
# Назначение мандатных привилегий пользователю bacula
usermac -m 0:0 -c 0:0 bacula
 
# Скрываем системных пользователей в окне авторизации ОС СН
sed -i -e '/^HiddenUsers/s/=.*/=root,fly-dm,ossec,ossecm,ossecr,bacula,modisa,paramreg/g' /etc/X11/fly-dm/fly-dmrc
 
# Перезагружаем службу fly-dm
service fly-dm restart

Установка пакетов

# Установить с диска ОС СН необходимые пакеты
DEBIAN_FRONTEND=noninteractive apt-get install -y bacula-server bacula-console bacula-sd bacula-fd bacula-traymonitor bacula-client bacula-common-pgsql bacula-director-pgsql bacula-sd-pgsql
 
# Выставить необходимые права доступа
chmod +x /etc/bacula/scripts/make_catalog_backup.pl
 
# Остановить службы
service bacula-director stop
service bacula-fd stop
service bacula-sd stop
 
# Добавить пользователя администратор в группу bacula
export ADMIN=admin
usermod -a -G bacula ${ADMIN}
 
# Удаление ранее созданной БД "bacula" и роли "bacula"
su - postgres - -c "dropdb --maintenance-db=postgres bacula"
su - postgres - -c "dropuser bacula"
 
# Создать новую БД "bacula"
#sudo -u postgres psql -c "CREATE DATABASE bacula ENCODING 'SQL_ASCII' TEMPLATE template0;"
su - postgres - -c "createdb -T template0 -E SQL_ASCII -O postgres bacula"
 
# Выполнить GRANT для доступа к БД "bacula"
cat <<EOF | su - postgres -c "echo && psql -t -q"
CREATE USER bacula LOGIN;
GRANT CONNECT ON DATABASE bacula TO public, bacula;
EOF
 
# Изменить sql скрипты по созданию БД и применения GRANT
sed -i -e "/^db_name/s/=.*/=bacula/g" /usr/share/bacula-director/make_postgresql_tables
sed -i -e "/^db_user/s/=.*/=bacula/g" /usr/share/bacula-director/grant_postgresql_privileges
sed -i -e "/^db_name/s/=.*/=bacula/g" /usr/share/bacula-director/grant_postgresql_privileges
sed -i -e "/^db_password/s/[= ].*/=/g" /usr/share/bacula-director/grant_postgresql_privileges
 
# Запустить sql скрипты по созданию БД и применения GRANT
su - postgres -c "/usr/share/bacula-director/make_postgresql_tables"
su - postgres -c "/usr/share/bacula-director/grant_postgresql_privileges"
 
# Создаем директории для хранения резервных копий
mkdir -p /opt/bacula/{backup,restore}
chown -R bacula:bacula /opt/bacula
chmod -R 700 /opt/bacula


# Настройка конфигурационных файлов
# При использовании ssl, пароль в конфигурационном файле не указывается
# Изменить конфигурационный файл /etc/bacula/bacula-dir.conf
grep -e "^Catalog" -A8 /etc/bacula/bacula-dir.conf
 Catalog {
  Name = MyCatalog
  dbdriver = "dbi:postgresql"; dbaddress = 127.0.0.1; dbport = 5432
  dbname = "bacula"; dbuser = "bacula"; dbpassword = ""
 }

 # Выставить необходимые права доступа на файлы
chmod 755 /etc/bacula
chmod 640 /etc/bacula/*.conf
chmod 600 /etc/bacula/common_default_passwords
chown root:root     /etc/bacula
chown root:bacula   /etc/bacula/bacula-dir.conf
chown root:root     /etc/bacula/bacula-fd.conf
chown bacula:bacula /etc/bacula/bacula-sd.conf
chown root:bacula   /etc/bacula/bconsole.conf
chown root:bacula   /etc/bacula/tray-monitor.conf
chown root:root     /etc/bacula/common_default_passwords

# Создать файл /etc/cron.d/exim_clean для очистки exim от сообщений ОС
sed -i -e "/^QUEUERUNNER/s/=.*/='no'/" /etc/default/exim4
cat > /etc/cron.d/exim_clean<<EOF
0 */5 * * *   root    /bin/bash -c "exipick -zi | xargs exim -Mrm";
EOF
[[ ! -f /etc/default/exim4 ]] && rm /etc/cron.d/exim_clean
 
# Перезапустить службу
service cron restart

# Настройка SSL для работы с PostgreSQL 
apt-get install -y ca-certificates
 
# check key
ls -la /var/lib/postgresql/*/main/*.{crt,key}
    -r-------- 1 postgres postgres 1289 Авг 23 21:40 /var/lib/postgresql/9.3/main/client-ca.crt
    -r-------- 1 postgres postgres 1168 Авг 23 21:40 /var/lib/postgresql/9.3/main/postgresql.crt
    -r-------- 1 postgres postgres 1704 Авг 23 21:40 /var/lib/postgresql/9.3/main/postgresql.key
 
# Generate client CSR. CN must contain the name of the database role you will be using to connect to the database
openssl req -sha256 -new -nodes \
    -subj "/CN=bacula" \
    -out /usr/share/ca-certificates/postgresql/client-bacula.csr \
    -keyout /etc/ssl/private/client-bacula.key
# Sign a client certificate
openssl x509 -req -sha256 -days 365 \
    -in /usr/share/ca-certificates/postgresql/client-bacula.csr \
    -CA /usr/share/ca-certificates/postgresql/client-ca.crt \
    -CAkey /etc/ssl/private/client-ca.key \
    -CAcreateserial \
    -out /usr/share/ca-certificates/postgresql/client-bacula.crt
 
# Изменить конфигурационный файл pg_hba.conf
cd /var/lib/postgresql/*/main
sed -i -e "/.*bacula/d" pg_hba.conf
sed -i -e "/TYPE  DATABASE.*/a local   bacula   postgres   peer" pg_hba.conf
echo 'hostssl   bacula   bacula   127.0.0.1/32   cert' >>pg_hba.conf
 
# Перезапустить службу
#service postgresql restart
sudo -u postgres psql -c "select pg_reload_conf();"
 
# Скопировать SSL ключ в домашнюю директорию bacula для подключения к PostgreSQL
mkdir -p /var/lib/bacula/.postgresql/
cp -f /usr/share/ca-certificates/postgresql/root-ca.crt /var/lib/bacula/.postgresql/root.crt
cp -f /usr/share/ca-certificates/postgresql/client-bacula.crt /var/lib/bacula/.postgresql/postgresql.crt
cp -f /etc/ssl/private/client-bacula.key /var/lib/bacula/.postgresql/postgresql.key
chmod 755 /var/lib/bacula/.postgresql
chmod 600 /var/lib/bacula/.postgresql/*
chown bacula:bacula -R /var/lib/bacula/.postgresql
 
# Скопировать SSL ключ в домашнюю директорию root для подключения к PostgreSQL (иначе не работает: bacula-dir -tc /etc/bacula/bacula-dir.conf)
mkdir -p /root/.postgresql
cp -axfr /var/lib/bacula/.postgresql/* /root/.postgresql/.
 
# Проверить возможность подключиться по SSL
su - bacula - -c "psql -h localhost -d bacula -l"
 
# (/usr/sbin/nologin : /bin/bash)
su bacula
export PGSSLCERT=/var/lib/bacula/.postgresql/postgresql.crt
export PGSSLKEY=/var/lib/bacula/.postgresql/postgresql.key
export PGSSLROOTCERT=/var/lib/bacula/.postgresql/root.crt
psql "postgresql://localhost/?sslmode=verify-ca" -l


# Проверка корректности конфигурационных файлов
bacula-dir -tc /etc/bacula/bacula-dir.conf
bacula-sd -tc /etc/bacula/bacula-sd.conf
bacula-fd -tc /etc/bacula/bacula-fd.conf
 
# Перезапускаем службы
service bacula-fd stop
service bacula-sd stop
service bacula-director stop
[ -d "/run/bacula" ] && rm -f /run/bacula/*.pid
/bin/bash -c ">/var/log/bacula/bacula.log"
service bacula-director start
sleep 2
service bacula-fd start
service bacula-sd start

# Для работы в консоли bacula
/usr/bin/bconsole -c /etc/bacula/bconsole.conf<<END_OF_DATA 
wait
list media
quit
END_OF_DATA | grep -i "Volume01" | wc -l
 
/usr/bin/bconsole -c /etc/bacula/bconsole.conf<<END_OF_DATA
wait
label pool=File volume=Volume01
wait
quit
END_OF_DATA
 
# delete volume=Volume01 yes
# rm -f /opt/bacula/backup/Volume01
 
/usr/bin/bconsole -c /etc/bacula/bconsole.conf<<END_OF_DATA
wait
messages
END_OF_DATA

##############
### MANUAL ###
##############

#run console bacula
bconsole
 
label    # Create a Label
Volume01 # Ввести имя Тома
2        # Выбрать хранилище с параметрами (Name=File, Maximum Volume Bytes = 50G)
 
run     # Запустить задание (создать резервную копию)
1       #1: Backup_dir_root
 
run     # Запустить задание (восстановить резервную копию в выбранную ранее директорию /opt/bacula/restore)
3       #3: Restore_dir_root
 
messages        # Вывести последние сообщения
status director # Вывести состояние заданий и хранилища
restore all     # Восстановить все файлы из выбранного бекапа
exit            # Выйти из bacula
