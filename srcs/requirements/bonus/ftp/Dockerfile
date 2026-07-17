FROM alpine:3.23

RUN apk add --no-cache vsftpd

COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf

COPY tools/init_ftp.sh /init_ftp.sh
RUN chmod +x /init_ftp.sh

EXPOSE 21
EXPOSE 21100-21110

ENTRYPOINT ["/init_ftp.sh"]
CMD ["vsftpd", "/etc/vsftpd/vsftpd.conf"]