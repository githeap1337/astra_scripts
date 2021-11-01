#!/bin/bash

# Необходимо соблюдать порядок нумерации правил внутри конфигурационных файлов. 
# Также нужно внимательно смотреть - в какую группу ставится правило. 
# Первые две цифры в ID правила должны быть эквивалентны первым цифрам ID группы.

# TODO: перенести в скрипт
# Изменить конфигурационный файл /var/ossec/rules/afick.xml (добавляем после блока <rule id="170000" level="12">)
<rule id="170001" level="12">
    <decoded_as>afick</decoded_as>
    <match>new file</match>
    <description>Новый файл в контролируемой директории.</description>
</rule>
<rule id="170002" level="12">
    <decoded_as>afick</decoded_as>
    <match>new directory</match>
    <description>Новая папка в контролируемой директории.</description>
</rule>
