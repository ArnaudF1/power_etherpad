#!/usr/bin/env bash

function _USAGE
{
cat << EOF
Usage :
    ${_SCRIPT_NAME} [OPTIONS]

Options :
    -u  website_url     website url (ex: http://mydomain.ovh)
    -d  documentroot    documentroot directory relative to home directory (ex: www)
    -e  entrypoint      entrypoint (ex: app.py, index.js, config.ru)
    -p  publicdir       publicdir directory relative to documentroot (ex: public)
    -v  version         etherpad version to install
    -h                  show this message
Ex :
    ${_SCRIPT_NAME} -u http://mydomain.ovh -d www -e app.py -p public

EOF
exit 1
}

function _LOGS
{
    local _LEVEL="${1}"
    local _MESSAGE="${2}"
    local _DATE="$(date --iso-8601=seconds)"
    local _LOGS_MESSAGE="[${_DATE}]  ${_LEVEL} ${_MESSAGE}"
    echo -e "${_LOGS_MESSAGE}"
}

function _GET_OPTS
{
    local _SHORT_OPTS="u:d:e:p:v:h";
    local _OPTS=$(getopt \
        -o "${_SHORT_OPTS}" \
        -n "${_SCRIPT_NAME}" -- "${@}")

    eval set -- "${_OPTS}"

    while true ; do
        case "${1}" in
            -u)
                _URL_OPT=${2}
                shift 2
                ;;
            -d)
                _DOCUMENTROOT_OPT=${2}
                shift 2
                ;;
            -e)
                _ENTRYPOINT_OPT=${2}
                shift 2
                ;;
            -p)
                _PUBLICDIR_OPT=${2}
                shift 2
                ;;
            -v)
                _VERSION_OPT=${2}
                shift 2
                ;;
            -h|--help)
                _USAGE
                shift
                ;;
            --) shift ; break ;;
        esac
    done
}

function _CHECK_OPTS
{
    if [ -z "${_DOCUMENTROOT_OPT}" ]
    then
        _LOGS "ERROR" "documentroot cannot be empty"
        exit 1
    fi
    if [ -z "${_URL_OPT}" ]
    then
        _LOGS "ERROR" "website_url cannot be empty"
        exit 1
    fi
    if [ -z "${_ENTRYPOINT_OPT}" ]
    then
        _LOGS "ERROR" "entrypoint cannot be empty"
        exit 1
    fi
    if [ -z "${_PUBLICDIR_OPT}" ]
    then
        _LOGS "ERROR" "publicdir cannot be empty"
        exit 1
    fi

    if [ -z "${_VERSION_OPT}" ]
    then
        _LOGS "ERROR" "version cannot be empty"
        exit 1
    fi

    if [ -z "${HOME}" ]
    then
        _LOGS "ERROR" "home env var empty stopping"
        exit 1
    fi
}

function _LOAD_ENV
{
    source /etc/ovhconfig.bashrc
    passengerConfig
}

function _PRINT_ENV
{
    cat << EOF
==============================================================
OVH_APP_ENGINE=${OVH_APP_ENGINE}
OVH_APP_ENGINE_VERSION=${OVH_APP_ENGINE_VERSION}
OVH_ENVIRONMENT=${OVH_ENVIRONMENT}
PATH=${PATH}
==============================================================
EOF
}

function _REMOVING_OLD_DOCUMENTROOT
{
    _LOGS "INFO" "removing old documentroot"
    rm -rf "${HOME:?}"/"${_DOCUMENTROOT_OPT}"
}

function _CREATING_DOCUMENTROOT
{
    _LOGS "INFO" "creating documentroot"
    mkdir -p "${HOME}"/"${_DOCUMENTROOT_OPT}"
}


function _DOWNLOADING
{
    _LOGS "INFO" "Download Etherpad archive"
    curl --silent --fail --location -o "${HOME}"/"${_DOCUMENTROOT_OPT}"/etherpad.tar.gz https://github.com/ether/etherpad-lite/archive/"${_VERSION_OPT}".tar.gz
}

function _EXTRACTING
{
    _LOGS "INFO" "extracting Etherpad archive"
    tar xzf "${HOME}"/"${_DOCUMENTROOT_OPT}"/etherpad.tar.gz --no-same-permissions --strip 1 -C "${HOME}"/"${_DOCUMENTROOT_OPT}"
    rm -f "${HOME}"/"${_DOCUMENTROOT_OPT}"/etherpad.tar.gz
}

function _INSTALL_DEPS
{
    cd "${HOME}"/"${_DOCUMENTROOT_OPT}"
    bash bin/installDeps.sh
}

function _CREATING_ENTRYPOINT
{
    _LOGS "INFO" "creating entrypoint"
    _VERSION=$(cat "${HOME}"/"${_DOCUMENTROOT_OPT}"/src/package.json | python -c 'import json,sys;print(json.load(sys.stdin)["version"])')
    if [ "$(echo -e "1.8.7\n${_VERSION}" | sort -rV | head -1)" == "${_VERSION}" ]
    then
    cat << 'EOF' > "${HOME}"/"${_DOCUMENTROOT_OPT}"/"${_ENTRYPOINT_OPT}"
'use strict';
const server = require('./src/node/server');
server.start();
EOF
    else
        ln -fs  src/node/server.js "${HOME}"/"${_DOCUMENTROOT_OPT}"/"${_ENTRYPOINT_OPT}"
    fi
}

function _RESTARTING
{
    _LOGS "INFO" "restarting"
    mkdir -p "${HOME}"/"${_DOCUMENTROOT_OPT}"/tmp
    touch "${HOME}"/"${_DOCUMENTROOT_OPT}"/tmp/restart.txt
}

function _SLEEPING
{
    _LOGS "INFO" "wait 30s for NFS file propagation"
    sleep 30
}

### MAIN
set -e
set -o pipefail
_SCRIPT_NAME=$(basename "${0}")
_GET_OPTS "${@}"
_CHECK_OPTS
_LOAD_ENV
_PRINT_ENV
_REMOVING_OLD_DOCUMENTROOT
_CREATING_DOCUMENTROOT
_DOWNLOADING
_EXTRACTING
_INSTALL_DEPS
_CREATING_ENTRYPOINT
_RESTARTING
_SLEEPING
_LOGS "INFO" "job is done"
