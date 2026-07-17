#!/bin/sh

if ! id "$FTP_USER" >/dev/null 2>&1; then
  adduser -D -h /var/www/html "$FTP_USER"
  echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
  echo "$FTP_USER" > /etc/vsftpd/vsftpd.userlist
fi

exec "$@"