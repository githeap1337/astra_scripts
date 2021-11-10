#!/bin/bash

#################################################
### Блокировка устройств в udev в Astra Linux ###
#################################################

# http://yztm.ru/lekc/l8/
#  в составе изделия по USB к ПЭВМ подключаются:
# мышка (символьное)
# принтер (символьное)
# привод оптических дисков (блочное)
# Эти устройства необходимо разрешить по VendorID, DeviceID, serial number и прочим параметрам
# /etc/parsec/PDAC/devices.cfg - база учета устройств в parsec
# /etc/udev/rules.d - правила для менеджера устройств udev

#####################################
### Поиск устройств через консоль ###
#####################################

# Рассматривается на примере привода чтения/записи оптических дисков.
# Запустить монитор для отслеживания подключаемых устройств
udevadm monitor --env
 
# После подключения устройства смотрим их короткий список
lsusb
 
# И в расширенном виде
lsusb -v
 
# Вывести наименование usb hub
lsusb -v | grep "Host"
 
#  Собираем информацию о серийном номере, производителе (/3-2.X - плавающее значение, берется из выдачи предыдущих команд)
udevadm info -a -p /sys/bus/usb/devices/3-2.X
 
# вывести все атрибуты устройства которые можно использовать по подключеному устройству /dev/sdc
udevadm info -a -n /dev/sdb
 
# Перезагрузить правила
udevadm trigger
udevadm control --reload-rules && service udev restart 

#######################
### Создание правил ###
#######################

# Создаем правила для комплекта периферии
mcedit /etc/udev/rules.d/70-usb.rules
 
    # Skeep if not USB device
    # SUBSYSTEM!="usb", GOTO="usb_rules_end"
    
    # Skeep if block device (flash, disk) - Optical Drive?
    # SUBSYSTEM=="block", GOTO="cdrom_end"
    
    # Skeep if remove actions
    ACTION=="remove", GOTO="usb_rules_end"
    
    # Enable mouse (+)
    #ACTION=="add", ENV{ID_INPUT_MOUSE}=="1" RUN+="/bin/sh -c 'echo 1 > /sys/$devpath/authorized'"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1bcf", ATTR{idProduct}=="0824", ATTRS{manufacturer}=="SunplusIT", ATTRS{product}=="1bcf/824/522", ATTR{serial}=="SunplusIT_Smart" RUN+="/bin/sh -c 'echo 1 > /sys/$devpath/authorized'"
    
    # Enable optical disk drive
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="1887", ATTR{manufacturer}=="Hitachi-LG Data Storage Inc", ATTR{product}=="Portable Super Multi Drive", ATTR{serial}=="K54HAD83547" RUN+="/bin/sh -c 'echo 1 > /sys/$devpath/authorized'"
    
    # Enable printer
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", ATTR{idProduct}=="331e", ATTR{manufacturer}=="Samsung Electronics Co., Ltd.", ATTR{product}=="M262x 282x Series", ATTR{serial}=="ZD1UB8GJ7B0023N" RUN+="/bin/sh -c 'echo 1 > /sys/$devpath/authorized'"
    
    # Disable all usb devices (first start OS)
    #ACTION=="add", SUBSYSTEM=="usb", ACTION=="add", SUBSYSTEM=="usb", RUN+="/bin/sh -c 'for host in /sys/bus/usb/devices/usb*; do echo 0 > $host/authorized_default; done'"



# Правило сгенерированное parsec

### МЫШКА ###
mcedit /etc/udev/rules.d/99zz_PDAC_LOCAL_Optical_Mouse.rules

    #Parsec DevAC udev rule 4 device "not descripted"
    ENV{ID_SERIAL}=="PixArt_Microsoft_USB_Optical_Mouse", ENV{ID_VENDOR}=="PixArt", ENV{ID_VENDOR_ENC}=="PixArt", ENV{ID_VENDOR_ID}=="045e", ENV{ID_REVISION}=="0100", ENV{ID_MODEL}=="Microsoft_USB_Optical_Mouse", ENV{ID_BUS}=="usb", ENV{ID_MODEL_ENC}=="Microsoft\x20USB\x20Optical\x20Mouse", ENV{ID_MODEL_ID}=="00cb", ENV{ID_SERIAL}=="PixArt_Microsoft_USB_Optical_Mouse", ENV{ID_VENDOR}=="PixArt", ENV{ID_VENDOR_ENC}=="PixArt", ENV{ID_VENDOR_ID}=="045e", ENV{ID_REVISION}=="0100", ENV{ID_MODEL}=="Microsoft_USB_Optical_Mouse", ENV{ID_BUS}=="usb", ENV{ID_MODEL_ENC}=="Microsoft\x20USB\x20Optical\x20Mouse", ENV{ID_MODEL_ID}=="00cb", OWNER="root", GROUP="users", MODE="644", PDPL="0:0:0x0:0x0!:", AUDIT="o:0x0:0x0", GOTO="BLOCK_DEV"
    GOTO="END"
    LABEL="BLOCK_DEV"
    SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="?*", NAME="%k_$env{ID_FS_TYPE}", SYMLINK+="%k"
    LABEL="END"
 
### DVD ПРИВОД ###
mcedit /etc/udev/rules.d/99zz_PDAC_LOCAL_ASUS_Optical_Disk_Drive.rules

    #Parsec DevAC udev rule 4 device "not descripted"
    ENV{ID_MODEL}=="SDRW-08D2S-U", ENV{ID_SERIAL}=="ASUS_SDRW-08D2S-U_S13V6YAF500LPM-0:0", ENV{ID_VENDOR_ID}=="0e8d", ENV{ID_SERIAL_SHORT}=="S13V6YAF500LPM", ENV{ID_VENDOR}=="ASUS", OWNER="root", GROUP="cdrom", MODE="644", PDPL="0:0:0x0:0x0!:", AUDIT="o:0x3ff:0x0", GOTO="BLOCK_DEV"
    GOTO="END"
    LABEL="BLOCK_DEV"
    SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="?*", NAME="%k_$env{ID_FS_TYPE}", SYMLINK+="%k"
    LABEL="END"
 
### ПРИНТЕР ###
 
mcedit /etc/udev/rules.d/99zz_PDAC_LOCAL_Samsung_M2830DW_Printer.rules

    #Parsec DevAC udev rule 4 device "not descripted"
    ENV{PRODUCT}=="4e8/3328/100", OWNER="root", GROUP="lp", MODE="644", PDPL="0:0:0x0:0x0!:", AUDIT="o:0x0:0x0", GOTO="BLOCK_DEV"
    GOTO="END"
    LABEL="BLOCK_DEV"
    SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="?*", NAME="%k_$env{ID_FS_TYPE}", SYMLINK+="%k"
    LABEL="END"


# Добавление возможности монтирования
echo -e "\n/dev/sr* /*home/*/media/* udf,iso9660 user,noauto 0 0" >> /etc/fstab