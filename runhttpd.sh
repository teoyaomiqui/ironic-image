#!/usr/bin/bash

IP=${IP:-"172.22.0.1"}
HTTP_PORT=${HTTP_PORT:-"80"}
IRONIC_INSPECTOR_PORT=${IRONIC_INSPECTOR_PORT:-"30050"}

mkdir -p /shared/html
chmod 0777 /shared/html

# Copy files to shared mount
cp /tmp/inspector.ipxe /shared/html/inspector.ipxe
cp /tmp/dualboot.ipxe /shared/html/dualboot.ipxe

# Use configured values
sed -i -e s/IRONIC_IP/$IP/g -e s/HTTP_PORT/$HTTP_PORT/g -e s/INSPECTOR_PORT/$IRONIC_INSPECTOR_PORT/g /shared/html/inspector.ipxe

sed -i 's/^Listen .*$/Listen '"$HTTP_PORT"'/' /etc/httpd/conf/httpd.conf
sed -i -e 's|\(^[[:space:]]*\)\(DocumentRoot\)\(.*\)|\1\2 "/shared/html"|' \
    -e 's|<Directory "/var/www/html">|<Directory "/shared/html">|' \
    -e 's|<Directory "/var/www">|<Directory "/shared">|' /etc/httpd/conf/httpd.conf

# Remove log files from last deployment
rm -rf /shared/log/httpd
   
mkdir -p /shared/log/httpd

# Make logs available in shared mount
touch /shared/log/httpd/access_log
ln -s /shared/log/httpd/access_log /var/log/httpd/access_log
touch /shared/log/httpd/error_log
ln -s /shared/log/httpd/error_log /var/log/httpd/error_log

# Allow external access
if ! iptables -C INPUT -p tcp --dport $HTTP_PORT -j ACCEPT 2>/dev/null ; then
    iptables -I INPUT -p tcp --dport $HTTP_PORT -j ACCEPT
fi

/usr/sbin/httpd &

/bin/runhealthcheck "httpd" $HTTP_PORT &>/dev/null &
sleep infinity

