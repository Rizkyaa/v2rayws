#!/bin/bash
set -e

if [ $# -ne 1 ]; then
	echo "Usage: $0 domain_name" >&2
	exit 1
fi

do_name=$1

apt-get update && apt-get -y upgrade
apt-get -y install nginx socat curl wget 
hostnamectl set-hostname $do_name
curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
chmod +x install-release.sh
./install-release.sh
systemctl stop nginx
cat <<EOF >>/etc/nginx/sites-available/ssl
server {
    listen 16432 ssl default_server;
    listen [::]:16432 ssl default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    ssl on;
    ssl_certificate       /root/v2rayws/p1.crt;
    ssl_certificate_key   /root/v2rayws/p2.key;
    ssl_protocols         TLSv1 TLSv1.1 TLSv1.2 TlSv1.3;
    ssl_ciphers           HIGH:!aNULL:!MD5;
    server_name           $do_name;

    location /ws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:16430;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
ln -s /etc/nginx/sites-available/ssl /etc/nginx/sites-enabled/
rm -f /etc/v2ray/config.json
cat <<EOF >>/usr/local/etc/v2ray/config.json
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": 16430,
      "listen":"127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "b831381d-6324-4d53-ad4f-8cda48b30811",
            "alterId": 64,
            "security": "auto",
            "level": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ws"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

systemctl restart nginx
systemctl enable nginx
systemctl restart v2ray
systemctl enable v2ray

netstat -lntp
echo "done, enjoy!"


