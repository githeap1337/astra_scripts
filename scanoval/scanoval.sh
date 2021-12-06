#!/bin/bash

############################################################
### Установка сканера уязвимостей ScanOval для AL SE 1.6 ###
############################################################

mkdir -p /tmp/scanoval/ && cp scanoval-repo-alse16.tar.gz scanovalcontent_alse.deb /tmp/scanoval/
cd /tmp/scanoval/ && tar -C /var/lib -xvf scanoval-repo-alse16.tar.gz
apt-key add /var/lib/scanoval/repo/PUBLIC-GPG-KEY-scanoval
echo "deb file:///var/lib/scanoval/repo smolensk main content" >>/etc/apt/sources.list
echo 'deb ftp://10.200.40.86/astra/1.6/mounted-iso-main smolensk main contrib non-free' >/etc/apt/sources.list.d/local.repository.list
apt-get update
apt-get install libopenscap8 openssl scanoval
dpkg-deb –x scanovalcontent_alse.deb /
