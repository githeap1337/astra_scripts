# Установка и настройка PostgreSQL
# Для универсальности использования данной стать в разных проектах, 
# задаем переменные окружения для их дальнейшего использования в конфигурационных файлах. 

# для спо 
# export PGPATH="/drbd/postgresql"

# default
export PGPATH="/var/lib/postgresql"

export PGVER="9.6"
export PGCFG="/etc/postgresql/${PGVER}/main"
export PGDATA="${PGPATH}/${PGVER}/main"

####################################
### Установка пакетов PostgreSQL ###
####################################

# Установку и проверку пакетов PostgreSQL выполнять на всех серверах, при необходимости на АРМ.

# Генерируем en_US.UTF-8, ru_RU.UTF-8
sed -i -e "/en_US.UTF-8/s/#//g; /ru_RU.UTF-8/s/#//g" /etc/locale.gen
grep -v "^#" /etc/locale.gen
locale-gen ru_RU.UTF-8 en_US.UTF-8
update-locale LANG=ru_RU.UTF-8
 
# Текущий список установленных пакетов postgresql
dpkg --get-selections | grep postgres
 
# Установка пакетов postgresql
apt install postgresql postgresql-${PGVER} postgresql-astra postgresql-client postgresql-client-${PGVER} postgresql-client-common postgresql-common -y
 
# fix: Use of uninitialized value $lib_path in concatenation (.) or string at /usr/bin/psql line 139
sed -i -e '/lib_path)/s/=.*/= "\/lib\/x86_64-linux-gnu";/g' /usr/bin/psql
 
# Установка PgAdmin3
apt install pgadmin3 pgadmin3-data -y
 
# Остановить службу postgresql
systemctl stop postgresql
 
# Включить автозагрузку postgresql (если не используется pacemaker)
systemctl enable postgresql
 
# Настройка пользователя
usermod -s /bin/bash postgres
passwd -d postgres
usercaps -zd postgres
usermac -zd postgres
 
# Создать директорию под лог postgresql
mkdir /var/log/postgresql 2>/dev/null
rm -f /var/log/postgresql/*
rm -f /var/lib/postgresql/${PGVER}/main/pg_log/*
chmod 755 /var/log/postgresql
chown postgres:postgres /var/log/postgresql
mkdir /var/run/postgresql 2>/dev/null
chmod 775 /var/run/postgresql
chown postgres:postgres /var/run/postgresql
 
# Разрешить пользователю postgres читать метки
usermod -a -G shadow,sys postgres
setfacl -d -m u:postgres:r  /etc/parsec/macdb
setfacl -R -m u:postgres:r  /etc/parsec/macdb
setfacl    -m u:postgres:rx /etc/parsec/macdb
setfacl -d -m u:postgres:r  /etc/parsec/capdb
setfacl -R -m u:postgres:r  /etc/parsec/capdb
setfacl    -m u:postgres:rx /etc/parsec/capdb

# Отключить необходимость создавать пользователя в ОС для авторизации в PostgreSQL (при необходимости)
sed -i -e '/^zero/s/:.*/: yes/' /etc/parsec/mswitch.conf

#############################################
### Создать кластер баз данных PostgreSQL ###
#############################################

# Создать новый кластер в замен созданного ранее, предыдущий будет удален (при необходимости)
# Остановить службу postgresql
systemctl stop postgresql
 
# Удалить директории, если необходима повторная инициализации
rm -rf /var/lib/postgresql/${PGVER}/main
rm -f /etc/postgresql/${PGVER}/main/*.conf*
 
# Создать директорию хранения БД
mkdir -p $PGPATH
[ -d "$PGPATH" ] && chmod 700 $PGPATH && chown postgres:postgres -R $PGPATH
 
# Проверяем какие присутствуют кодировки (ru_RU.utf8; en_US.utf8)
locale -a |grep utf8
  
# Проверяем и убиваем старые процессы, если такие имеются
ps aux |grep -v grep |grep postgres
 
# Выполняем инициализацию
ls -la /usr/lib/postgresql/${PGVER}/bin
rm -f /etc/postgresql/${PGVER}/main/*.conf
sudo -u postgres /usr/lib/postgresql/${PGVER}/bin/initdb -D $PGDATA --locale=ru_RU.utf8 --encoding=UTF8 --lc-messages=en_US.utf8

####################################
### Базовая настройка PostgreSQL ###
####################################

# При использовании в проекте кластер, настройку выполнять на сервере - Мастер.
# Переместить конфигурационные файлы и создать link
mkdir -p /etc/postgresql/${PGVER}/main
find /etc/postgresql/${PGVER} -type f -name "*.conf" -exec mv {} "${PGDATA}/" \;
ln -sf "${PGDATA}/"*.conf "${PGCFG}/"
 
# Создать резервные копии конфигурационных файлов
find ${PGDATA} -type f -regex ".*.conf.[0-9]+" -delete
find ${PGDATA} -type f -name "*.conf" -exec cp {}{,.`date +%s`} \;
 
# Перед настройкой параметров, убирать перед изменяемыми настройками символ комментарий (#)
# Основные настройки
export PGCFG1="ac_audit_file ac_debug_print data_directory hba_file ident_file listen_addresses port max_connections unix_socket_directories ac_ignore_socket_maclabel"
# Настройки логов
export PGCFG2="wal_level log_destination logging_collector log_directory log_filename log_file_mode log_truncate_on_rotation log_rotation_age log_rotation_size"
export PGCFG3="client_min_messages log_min_messages log_min_error_statement log_connections log_disconnections log_line_prefix log_statement"
# Настройки часового пояса
export PGCFG4="log_timezone timezone"
# Увеличение производительности
export PGCFG5="shared_buffers temp_buffers work_mem maintenance_work_mem fsync synchronous_commit commit_delay wal_sync_method seq_page_cost random_page_cost cpu_tuple_cost cpu_index_tuple_cost cpu_operator_cost effective_cache_size max_locks_per_transaction max_pred_locks_per_transaction"
 
cd $PGDATA
for value in $PGCFG1 $PGCFG2 $PGCFG3 $PGCFG4 $PGCFG5; do sed -i -e "/^[[:space:]\t#]\+${value}[=[:space:]\t]\+/s/^[[:space:]\t#]\+//" postgresql.conf; done
 
# Основные настройки
sed -i -e "/^ac_debug_print/s/[= ][^\t#]*/ = false/" postgresql.conf
sed -i -e "/^ac_audit_file/s/[= ][^\t#]*/ = '${PGCFG//\//\\/}\/pg_audit.conf'/" postgresql.conf
sed -i -e "/^data_directory/s/[= ][^\t#]*/ = '${PGDATA//\//\\/}'/" postgresql.conf
sed -i -e "/^hba_file/s/[= ][^\t#]*/ = '${PGCFG//\//\\/}\/pg_hba.conf'/" postgresql.conf
sed -i -e "/^ident_file/s/[= ][^\t#]*/ = '${PGCFG//\//\\/}\/pg_ident.conf'/" postgresql.conf
sed -i -e "/^listen_addresses/s/[= ][^\t#]*/ = '0.0.0.0'/" postgresql.conf
sed -i -e "/^port/s/[= ][^\t#]*/ = 5432/" postgresql.conf
sed -i -e "/^max_connections/s/[= ][^\t#]*/ = 100/" postgresql.conf
sed -i -e "/^unix_socket_directories/s/[= ][^\t#]*/ = '\/var\/run\/postgresql\/'/" postgresql.conf
 
# Мандатное разграничение доступа
sed -i -e "/^ac_ignore_socket_maclabel/s/[= ][^\t#]*/ = true/" postgresql.conf
sed -i -e "/^ac_ignore_server_maclabel/s/[= ][^\t#]*/ = true/" postgresql.conf
 
# Настройки логов
sed -i -e "/^wal_level/s/[= ][^\t#]*/ = 'minimal'/" postgresql.conf
sed -i -e "/^log_destination/s/[= ][^\t#]*/ = 'stderr'/" postgresql.conf
sed -i -e "/^logging_collector/s/[= ][^\t#]*/ = on/" postgresql.conf
sed -i -e "/^log_directory/s/[= ][^\t#]*/ = '\/var\/log\/postgresql'/" postgresql.conf
sed -i -e "/^log_filename/s/[= ][^\t#]*/ = 'postgresql-%Y-%m-%d.log'/" postgresql.conf
sed -i -e "/^log_file_mode/s/[= ][^\t#]*/ = 0600/" postgresql.conf
sed -i -e "/^log_truncate_on_rotation/s/[= ][^\t#]*/ = on/" postgresql.conf
sed -i -e "/^log_rotation_age/s/[= ][^\t#]*/ = 1d/" postgresql.conf
sed -i -e "/^log_rotation_size/s/[= ][^\t#]*/ = 10000/" postgresql.conf
sed -i -e "/^client_min_messages/s/[= ][^\t#]*/ = notice/" postgresql.conf
sed -i -e "/^log_min_messages/s/[= ][^\t#]*/ = warning/" postgresql.conf
sed -i -e "/^log_min_error_statement/s/[= ][^\t#]*/ = error/" postgresql.conf
sed -i -e "/^log_connections/s/[= ][^\t#]*/ = off/" postgresql.conf
sed -i -e "/^log_disconnections/s/[= ][^\t#]*/ = off/" postgresql.conf
sed -i -e "/^log_line_prefix/s/[= ][^\t#]*/ = '%t; %d %u %r %'/" postgresql.conf
sed -i -e "/^log_statement/s/[= ][^\t#]*/ = 'ddl'/" postgresql.conf
 
# Увеличение производительности
sed -i -e "/^shared_buffers/s/[= ][^\t#]*/ = 2GB/" postgresql.conf
sed -i -e "/^temp_buffers/s/[= ][^\t#]*/ = 256MB/" postgresql.conf
sed -i -e "/^work_mem/s/[= ][^\t#]*/ = 64MB/" postgresql.conf
sed -i -e "/^maintenance_work_mem/s/[= ][^\t#]*/ = 256MB/" postgresql.conf
sed -i -e "/^fsync/s/[= ][^\t#]*/ = on/" postgresql.conf
sed -i -e "/^wal_sync_method/s/[= ][^\t#]*/ = fdatasync/" postgresql.conf
sed -i -e "/^synchronous_commit/s/[= ][^\t#]*/ = off/" postgresql.conf
sed -i -e "/^commit_delay/s/[= ][^\t#]*/ = 1000/" postgresql.conf
sed -i -e "/^seq_page_cost/s/[= ][^\t#]*/ = 1.0/" postgresql.conf
sed -i -e "/^random_page_cost/s/[= ][^\t#]*/ = 6.0/" postgresql.conf
sed -i -e "/^cpu_tuple_cost/s/[= ][^\t#]*/ = 0.01/" postgresql.conf
sed -i -e "/^cpu_index_tuple_cost/s/[= ][^\t#]*/ = 0.0005/" postgresql.conf
sed -i -e "/^cpu_operator_cost/s/[= ][^\t#]*/ = 0.0025/" postgresql.conf
sed -i -e "/^effective_cache_size/s/[= ][^\t#]*/ = 6GB/" postgresql.conf
sed -i -e "/^max_locks_per_transaction/s/[= ][^\t#]*/ = 256/" postgresql.conf
sed -i -e "/^max_pred_locks_per_transaction/s/[= ][^\t#]*/ = 256/" postgresql.conf
 
# Настройки часового пояса
# !!!!! НЕ менять зоны на другие, использовать только "Europe/Moscow"
sed -i -e "/^log_timezone/s/[= ][^\t#]*/ = 'Europe\/Moscow'/" postgresql.conf
sed -i -e "/^timezone/s/[= ][^\t#]*/ = 'Europe\/Moscow'/" postgresql.conf
 
# Откорректировать файл конфигурации pg_audit.conf
cd $PGDATA
sed -i -e "s/^success events*./#&/g" pg_audit.conf
# audit full user postgres
echo "success events mask = F00E7 failure events mask = 0 user = postgres" >> pg_audit.conf
# audit small all users
echo "success events mask = F0707 failure events mask = FFFFF" >> pg_audit.conf
# audit full all users
#echo "success events mask = FFFFF failure events mask = FFFFF" >> pg_audit.conf
 
# Откорректировать файл конфигурации pg_hba.conf
cd $PGDATA
sed -i -e "s/^local*./#&/g; s/^host*./#&/g" pg_hba.conf
cat >> pg_hba.conf<<EOF
local   all   postgres                   peer
local   all   all                        peer
host    all   postgres  127.0.0.1/32     md5
host    all   all       127.0.0.1/32     trust
EOF
 
# Откорректировать файл конфигурации pg_ident.conf
cd $PGDATA
sed -i -e "/^local/d; /^host/d" pg_ident.conf
#cat >> pg_ident.conf<<EOF
#local          /(.*)              postgres
#host           /(.*)              postgres
#EOF
 
# Запустить службу
systemctl start postgresql
 
# Перезагрузить конфигурационный файл postgresql.conf
systemctl reload postgresql
invoke-rc.d postgresql reload
kill -HUP $(head -1 /var/lib/postgresql/9.6/main/postmaster.pid)
sudo -u  postgres psql -c "select pg_reload_conf();"
grep -i reloading /var/log/postgresql/*
    received SIGHUP, reloading configuration files

# Дополнительные настройки конфигурационного файла postgresql (при использовании ALD)
cd $PGDATA
 
# Настройки при использовании ALD
for value in krb_server_keyfile krb_srvname; do sed -i -e "/^[[:space:]\t#]\+${value}[=[:space:]\t]\+/s/^[[:space:]\t#]\+//" postgresql.conf; done
sed -i -e "/^krb_server_keyfile/s/[= ][^\t#]*/ = '${PGCFG//\//\\/}\/krb5.keytab'/" postgresql.conf
sed -i -e "/^krb_srvname/s/[= ][^\t#]*/ = 'postgres'/" postgresql.conf
 
# Reload config
systemctl reload postgresql

#####################
### Настройка SSL ###
#####################

# Создание SSL ключа для сервера PostgreSQL (при необходимости)


apt-get install -y ca-certificates
 
mkdir -p /usr/share/ca-certificates/postgresql
rm -f /usr/share/ca-certificates/postgresql/*
rm -f /etc/ssl/private/{root*.key,client*.key}
# Название организации и почта
ORGNAME='sp'
ORGEMAIL='support@sp.com' 
# Корневой сертификат сервера
openssl req -sha256 -new -x509 -days 3600 -nodes \
    -subj "/C=RU/O=${ORGNAME}/emailAddress=${ORGEMAIL}/CN=root-ca" \
    -out /usr/share/ca-certificates/postgresql/root-ca.crt \
    -keyout /etc/ssl/private/root-ca.key
# Генерируем запрос ключа
openssl req -sha256 -new -nodes \
    -subj "/C=RU/O=${ORGNAME}/emailAddress=${ORGEMAIL}/CN=srvdata" \
    -out /usr/share/ca-certificates/postgresql/root.csr \
    -keyout /etc/ssl/private/root.key
# Подписываем сертификат
openssl x509 -req -sha256 -days 3600 \
    -in /usr/share/ca-certificates/postgresql/root.csr \
    -CA /usr/share/ca-certificates/postgresql/root-ca.crt \
    -CAkey /etc/ssl/private/root-ca.key \
    -CAcreateserial \
    -out /usr/share/ca-certificates/postgresql/postgresql.crt
chown root:ssl-cert /etc/ssl/private/*
chmod 640 /etc/ssl/private/*
ln -sf /usr/share/ca-certificates/postgresql/root-ca.crt /etc/ssl/certs/root-ca.pem
update-ca-certificates
cp -f /usr/share/ca-certificates/postgresql/postgresql.crt ${PGDATA}/postgresql.crt
cp -f /etc/ssl/private/root.key ${PGDATA}/postgresql.key
chown postgres:postgres ${PGDATA}/postgresql.{crt,key}
chmod 400 ${PGDATA}/postgresql.{crt,key}
 
# Клиентский сертификат
# Создаем клиентский сертификат
openssl req -sha256 -new -x509 -days 3600 -nodes \
    -subj "/C=RU/O=${ORGNAME}/emailAddress=${ORGEMAIL}/CN=client-ca" \
    -out /usr/share/ca-certificates/postgresql/client-ca.crt \
    -keyout /etc/ssl/private/client-ca.key
cp -f /usr/share/ca-certificates/postgresql/client-ca.crt ${PGDATA}/client-ca.crt
chown postgres:postgres ${PGDATA}/client-ca.crt
chmod 400 ${PGDATA}/client-ca.crt
 
# Проверяем сертификат и ключ
openssl x509 -text < /usr/share/ca-certificates/postgresql/root-ca.crt
openssl x509 -noout -modulus -in /usr/share/ca-certificates/postgresql/postgresql.crt | md5sum
openssl req -noout -modulus -in /usr/share/ca-certificates/postgresql/root.csr | openssl md5
openssl rsa -noout -modulus -in /etc/ssl/private/root.key | md5sum

# Создание SSL ключа для пользователя postgres используя client-ca.crt
 openssl req -sha256 -new -nodes \
    -subj "/CN=postgres" \
    -out /usr/share/ca-certificates/postgresql/client-postgres.csr \
    -keyout /etc/ssl/private/client-postgres.key
openssl x509 -req -sha256 -days 3600 \
    -in /usr/share/ca-certificates/postgresql/client-postgres.csr \
    -CA /usr/share/ca-certificates/postgresql/client-ca.crt \
    -CAkey /etc/ssl/private/client-ca.key \
    -CAcreateserial \
    -out /usr/share/ca-certificates/postgresql/client-postgres.crt
 
mkdir -p /var/lib/postgresql/.postgresql
cp -f /usr/share/ca-certificates/postgresql/root-ca.crt /var/lib/postgresql/.postgresql/root.crt
cp -f /usr/share/ca-certificates/postgresql/client-postgres.crt /var/lib/postgresql/.postgresql/postgresql.crt
cp -f /etc/ssl/private/client-postgres.key /var/lib/postgresql/.postgresql/postgresql.key
chmod 755 /var/lib/postgresql/.postgresql/
chmod 600 /var/lib/postgresql/.postgresql/*
chown postgres:postgres -R /var/lib/postgresql/.postgresql

###############################
### Настройка ротации логов ###
###############################

# TODO: при copytruncate часть логов теряется
apt install logrotate -y
cp -axf /etc/cron.daily/logrotate /etc/cron.hourly/.
 
cat > /etc/logrotate.d/postgresql-common<<EOF
/var/log/postgresql/*.log {
    hourly
    size 100M
    rotate 1
    copytruncate
    compress
    maxage 0
    notifempty
    missingok
    sharedscripts
    postrotate
        find /var/log/postgresql/ -name "*.log*" -mtime +14 -delete;
    endscript
    su root root
}
EOF
 
chmod 644 /etc/logrotate.d/postgresql-common
logrotate -f /etc/logrotate.d/postgresql-common
