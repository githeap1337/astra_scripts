#!/bin/bash

# TODO: перенести в скрипт

# Изменить конфигурационный файл /var/ossec/etc/decoder.xml (добавляем после блока <!-- pam_unix-root -->)
<decoder name="pam_unix">
    <program_name></program_name>
    <prematch>pam_unix\.+ logname</prematch>
    <regex>user=(\S+)</regex>
    <order>user</order>
</decoder>
<decoder name="pam_unix-session_flydm">
    <program_name></program_name>
    <prematch>pam_unix\.+fly-dm</prematch>
    <regex>user (\S+)</regex>
    <order>user</order>
</decoder>
<decoder name="pam_unix-session_flywm">
    <program_name></program_name>
    <prematch>pam_unix\.+fly-wm</prematch>
    <regex>user=(\S+)</regex>
    <order>user</order>
</decoder>
 
# Изменить конфигурационный файл /var/ossec/etc/decoder.xml (добавляем после блока <!-- Администрирование -->)
<decoder name="fly-admin-gmc">
        <!--program_name>fly-admin-gmc</program_name-->
        <program_name></program_name>
        <prematch>fly-admin-gmc</prematch>
</decoder>
