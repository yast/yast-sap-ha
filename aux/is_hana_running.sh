#!/bin/bash
#

while true
do
        if [ "$( /usr/sap/hostctrl/exe/sapcontrol -nr 00 -function GetProcessList | grep hdbindexserver )" ]; then
                echo -n "RUN " >> /var/log/hana-state
                date >> /var/log/hana-state
        else
                echo -n "NOT " >> /var/log/hana-state
                date >> /var/log/hana-state
        fi
        sleep 1
done

