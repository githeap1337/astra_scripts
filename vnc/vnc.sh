# TigerVNC на Астре 1.6
# Установка пакета
apt install tigervnc-scraping-server xinetd
 
# Создание пароля
mkdir ~/.vnc
echo qwertyuiop | vncpasswd -f > ~/.vnc/passwd
 
# Без пароля
x0vncserver -display :0 -rfbport 5900 -UseIPv4=1 -UseIPv6=0 -AcceptKeyEvents=1 -SecurityTypes None -Log *:stderr:100
# При использовании пароля
x0vncserver -display :0 -rfbport 5900 -UseIPv4=1 -UseIPv6=0 -AcceptKeyEvents=1 -SecurityTypes VncAuth -PasswordFile ~/.vnc/passwd