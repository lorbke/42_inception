#!/bin/sh
openssl genrsa -out lorbke.42.fr.key 2048
openssl req -new -key lorbke.42.fr.key -out lorbke.42.fr.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=OrganizationalUnit/CN=lorbke.42.fr"
openssl x509 -req -days 9999 -in lorbke.42.fr.csr -signkey lorbke.42.fr.key -out lorbke.42.fr.crt
