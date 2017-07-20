#!/bin/bash

orig_path=$(pwd)
export Y2DEBUG=1
cd ..
export Y2DIR=src
yast2 sap_ha readconfig ${orig_path}/config.yml
cd $orig_path

