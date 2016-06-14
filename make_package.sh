#!/usr/bin/zsh

C_RED="\e[31m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_NONE="\e[0m"
NAME="yast2-sap-ha"
VERSION=$(grep 'Version:' package/${NAME}.spec | sed "s/^Version:\s*\([0-9.]*\)/\1/")
REMOTE_PROJECT="Devel:SAP:SLE-12:SP2"
# REMOTE_PROJECT="home:imanyugin:sap-ha"
REMOTE_PACKAGE=$NAME
IBS_PROJECT_DIR=$(realpath "../ibs/${REMOTE_PROJECT}/${REMOTE_PACKAGE}")
TMP_DIR="/tmp/suse-sap-ha/"

source ~/.zshrc

function usage(){
    echo "Usage:"
    echo "$(basename $0) [submit | log]"
}

function ask_show_log(){
    read "opn?Open the build logs? "
    if [[ "$opn" =~ ^[Yy]$ ]]; then
        less $1
    fi
}

# 1:ppath 2:name 3:log_name 4:["submit"|""]
function build_package(){
    local ppath=$1
    local name=$2
    local log_name=$3
    local submit=$4
    # echo "ppath=$ppath, name=$name, log_name=$log_name, submit=$submit"
    echo
    echo "${C_YELLOW}Building package $name${C_NONE}"
    echo
    cd $ppath
    fortune | cowsay
    echo

    iosc build > ${TMP_DIR}/$log_name 2>&1
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "${C_RED}Build failed!${C_NONE}"
        ask_show_log ${TMP_DIR}/$log_name
        exit 1
    fi

    grep --color=never -A2 "RPMLINT report" ${TMP_DIR}/$log_name
    echo
    echo "${C_GREEN}Build finished successfully${C_NONE}"
    echo

    if [ $submit -eq 1 ]; then
        iosc addremove
        iosc commit
        rc=$?
        if [ $rc -eq 0 ]; then
            echo
            echo "${C_YELLOW}Repository URLs:${C_NONE}"
            echo
            iosc repourls
            echo
            echo "${C_YELLOW}OBS URL:${C_NONE}"
            echo
            echo "https://build.suse.de/project/show/${REMOTE_PROJECT}"
            echo "https://build.suse.de/package/show/${REMOTE_PROJECT}/${REMOTE_PACKAGE}"
            echo
        fi
    fi

    echo
    echo "${C_YELLOW}Packages:${C_NONE}"
    echo
    tail -n2 ${TMP_DIR}/$log_name
    echo
    echo "${C_YELLOW}Project path:${C_NONE} ${IBS_PROJECT_DIR}"
    echo
}

declare SUBMIT
SUBMIT=0

if [ $# -eq 1 ]; then
    case "$1" in
        log)
            less "$TMP_DIR/osc_build.log"
            exit 0
            ;;
        submit)
            SUBMIT=1
            ;;
        "")
            ;;
        *)
            usage
            exit 1
            ;;
    esac
else
    if [ $# -ne 0 ]; then
        usage
        exit 1
    fi
fi

echo -n "${C_YELLOW}"
echo -n "Building $NAME ver. $VERSION "
if [ $SUBMIT -eq 1 ]; then
    echo "and submitting to the IBS"
else
    echo "without submitting"
fi
echo "Adding modified files to Git"
echo -n "${C_NONE}"
git add $(git ls-files --modified) 2>/dev/null
echo "${C_YELLOW}Making package tarball${C_NONE}"
mkdir -p ${TMP_DIR} 2>/dev/null
rake tarball >${TMP_DIR}/rake_tarball.log 2>&1
echo 
echo "${C_YELLOW}Copying the tarball and .spec...${C_NONE}"
echo
rm -rf ${IBS_PROJECT_DIR}/yast2-sap-ha*
cp -v package/yast2-sap-ha-${VERSION}.tar.bz2 package/yast2-sap-ha.changes\
 package/yast2-sap-ha-rpmlintrc package/yast2-sap-ha.spec ${IBS_PROJECT_DIR}

CWD=$(pwd)
build_package $IBS_PROJECT_DIR "yast2-sap-ha" "osc_build.log" $SUBMIT
cd $CWD
