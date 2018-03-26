#!/bin/bash

set -e

yum install -y httpd mod_ssl certbot-apache awscli
aws s3 cp s3://${bucket}/ssl.conf /etc/httpd/conf.d/ssl.conf
mkdir -p /etc/httpd/conf.d/sites
aws s3 cp s3://${bucket}/${hostname}-pre.conf /etc/httpd/conf.d/sites/${hostname}.conf
systemctl enable httpd
systemctl start httpd
certbot --apache --non-interactive --agree-tos --domains ${fqdn} --email ${email}
aws s3 cp s3://${bucket}/${hostname}-post.conf /etc/httpd/conf.d/sites/${hostname}.conf
aws s3 cp s3://${bucket}/${hostname}-le-ssl.conf /etc/httpd/conf.d/sites/${hostname}-le-ssl.conf
systemctl restart httpd
aws s3 cp s3://${bucket}/certbot.service /etc/systemd/system/certbot.service
aws s3 cp s3://${bucket}/certbot.timer /etc/systemd/system/certbot.timer
systemctl enable certbot.timer
systemctl start certbot.timer

