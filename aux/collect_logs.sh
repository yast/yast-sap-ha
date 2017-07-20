#!/bin/bash

FILE_LIST="
/var/lib/YaST2/sap_ha/cluster.config
/var/lib/YaST2/sap_ha/configuration_*_*.yml
/var/lib/YaST2/sap_ha/installation_log_*_*.txt
/var/lib/YaST2/sap_ha/installation_log_*_*.html
/var/log/messages
/var/log/pacemaker.log
/var/log/YaST2/y2log
/tmp/rpc_serv
/root/kill_rpc_server.log
"

function usage(){
    echo "Usage: $(basename $0) hostname1 hostname2 target_dir"
    exit 1
}

function die(){
    echo -e "\e[1m\e[31m$1\e[0m"
    exit 1
}

if [[ $# -lt 3 ]]; then
    usage
fi

HOSTNAME1=$1
HOSTNAME2=$2
TARGET_DIR=$3
SILENT=$4

if [[ -d $TARGET_DIR ]]; then
    if [[ -z $SILENT ]]; then
        echo -n "Direcory $TARGET_DIR exists. Overwrite? [y/N] "
        read answer
        if echo "$answer" | grep -iq "^y"; then
            echo ""
        else
            echo "Exiting"
            exit 0
        fi
    else
        mkdir $TARGET_DIR || die "Cannot create target directory $TARGET_DIR"
    fi
else
    mkdir $TARGET_DIR || die "Cannot create target directory $TARGET_DIR"
fi

HOSTNAMES="$HOSTNAME1 $HOSTNAME2"
for file in $FILE_LIST; do
    for hstname in $HOSTNAMES; do
        echo -n "Getting $file from $hstname"
        scp $hstname:$file $TARGET_DIR >/dev/null 2>&1; rc=$?
        echo "   rc=$rc"
        if [[ $rc -eq 0 ]]; then
            old_file="$TARGET_DIR/$(basename $file)"
            new_file="${TARGET_DIR}/${hstname}_$(basename $old_file)"
            echo $old_file '--->' $new_file
            mv $old_file $new_file
        fi
    done
done