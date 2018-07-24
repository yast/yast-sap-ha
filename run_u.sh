#!/bin/bash

export Y2DIR=src
#export Y2SLOG_DEBUG=1
#export Y2DEBUG=1
yast2 sap_ha readconfig ./aux/config_prd.yml
#yast2 sap_ha_unattended ./aux/config_prd.yml