#!/bin/bash

firewall-cmd --zone public --add-service ssh --permanent
firewall-cmd --zone public --add-service ssh
systemctl enable firewalld
systemctl start firewalld
