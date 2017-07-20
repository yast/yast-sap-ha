#!/bin/bash

while true; do
    RPC_PID=$(ps aux | grep [r]pc_server.rb | awk '{print $2}')
    if [[ $RPC_PID ]]; then
        echo "$(date) :: Killing RPC Server / $RPC_PID"
        kill -9 $RPC_PID
    else
        echo "$(date) :: No RPC detected"
    fi
    sleep 1
done