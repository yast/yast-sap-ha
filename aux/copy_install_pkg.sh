#!/bin/bash

HOSTS="nhana1 nhana2"
PACKAGE='yast2-sap-ha-1.0.2-1.noarch.rpm'


for host in $HOSTS; do
    print "Copying to $host"
    scp ../$PACKAGE ${host}:/root/
    ssh $host "zypper --non-interactive --no-gpg-checks in -f ./$PACKAGE"
done
