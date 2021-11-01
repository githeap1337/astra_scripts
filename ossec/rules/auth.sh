#!/bin/bash

# Необходимо соблюдать порядок нумерации правил внутри конфигурационных файлов. 
# Также нужно внимательно смотреть - в какую группу ставится правило. 
# Первые две цифры в ID правила должны быть эквивалентны первым цифрам ID группы.

# TODO: перенести в скрипт

# Изменить конфигурационный файл /var/ossec/rules/auth.xml (добавляем после блока <!-- Шаблон для событий аутентификации -->)
<rule id="120003" level="4">
    <decoded_as>pam_unix</decoded_as>
    <description>Аутентификация пользователя.</description>
</rule>
<rule id="120004" level="3">
    <decoded_as>pam_unix-session_flydm</decoded_as>
    <description>Аутентификация пользователя.</description>
</rule>
<rule id="120005" level="3">
    <decoded_as>pam_unix-session_flywm</decoded_as>
    <description>Аутентификация пользователя.</description>
</rule>
 
# Изменить конфигурационный файл /var/ossec/rules/auth.xml (добавляем после блока <!-- Шаблон для всех событий открытия сеанса -->)
<rule id="120013" level="5">
    <if_sid>120003</if_sid>
    <match>$BAD_AUTH</match>
    <group> - Неуспешно</group>
    <description>Ошибка аутентификации пользователя.</description>
</rule>
<rule id="120014" level="3">
    <if_sid>120004</if_sid>
    <match>session opened</match>
    <group> - Успешно</group>
    <description>Успешная аутентификация пользователя.</description>
</rule>
<rule id="120015" level="3">
    <if_sid>120004</if_sid>
    <match>session closed</match>
    <group> - Успешно</group>
    <description>Завершение сеанса.</description>
</rule>
