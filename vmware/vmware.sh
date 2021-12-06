#!/bin/bash
vmware-config-tools.pl <<EOF
yes
yes
yes
EOF
chmod 777 /mnt/hgfs/
useradd -m -d /home/admin -s /bin/bash -u 1001 -c "Администратор" -G astra-admin,lpadmin,lp,cdrom,floppy,plugdev admin && userdel -r user
echo "admin:asd" | chpasswd
cat > /home/admin/Desktop/Share.desktop <<EOF
[Desktop Entry]
Name[ru]=Share
Type=Link
NoDisplay=false
Hidden=false
URL=/mnt/hgfs
EOF
