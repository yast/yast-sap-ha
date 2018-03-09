#!/bin/bash

HANA_SID=$1

if [[ -z $HANA_SID ]]; then
    echo "Error: provide HANA SID as the first argument"
    exit 1
fi

# create user

HANA_SID_LOWER=$(echo "${HANA_SID}" | tr '[:upper:]' '[:lower:]')
HANA_USER="${HANA_SID_LOWER}adm"
HOME_DIR="/home/$HANA_USER"

getent passwd | grep "$HANA_USER"; rc=$?
if [[ rc -eq 0 ]]; then
    echo "User $HANA_USER exists"
else
    USER_PASSWORD=$(echo "Qwerty1234" | openssl passwd -1 -stdin)
    useradd -D -d "$HOME_DIR" -G users --create-home -p "$USER_PASSWORD"
fi

# create a fake HDB script

mkdir "$HOME_DIR/bin"
mv "HDB.sh" "$HOME_DIR/bin/HDB"
echo 'export PATH="$PATH:'"$HOME_DIR/bin\"" >> "$HOME_DIR/.bashrc"
