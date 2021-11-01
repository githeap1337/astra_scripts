#!/bin/bash

# Необходимо соблюдать порядок нумерации правил внутри конфигурационных файлов. 
# Также нужно внимательно смотреть - в какую группу ставится правило. 
# Первые две цифры в ID правила должны быть эквивалентны первым цифрам ID группы.

# TODO: перенести в скрипт
# Изменить конфигурационный файл /var/ossec/rules/parsec.xml (добавляем после блока <!-- Строки для идентификации мандатных прав -->)
<var name="SPO_NAME">MainFrame|Application|sipe22160</var>
 
# Изменить конфигурационный файл /var/ossec/rules/parsec.xml (добавляем после блока <group name="Контроль доступа к защищаемым файлам">)
<rule id="140000" level="3">
    <decoded_as>parselog-f-s</decoded_as>
    <description>Успешный доступ к защищаемому файлу.</description>
</rule>
 
# Изменить конфигурационный файл /var/ossec/rules/parsec.xml (добавляем после блока <rule id="140014" level="5">)
<rule id="140015" level="3">
    <if_sid>140000</if_sid>
    <match>$SPO_NAME</match>
    <description>Успешный запуск СПО.</description>
</rule>
