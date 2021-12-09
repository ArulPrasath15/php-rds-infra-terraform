#!/bin/bash
yum update -y
amazon-linux-extras install -y php7.2
yum install -y httpd git
systemctl start httpd
systemctl enable httpd
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
cd /var/www/html
git clone https://github.com/ArulPrasath15/php-app .
echo "${rds_dns}" > host.txt