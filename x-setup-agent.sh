#!/bin/bash

set -e

cd $(dirname $0)

# Setting default variables
ZBX_VERSION=3.4
# Loading project options and overriding default variables
if [ -e "../.env" ];  then source ../.env; fi

CODE=""
SERVER=""
LISTEN_IP=""
HOSTNAME=""
ENABLE_DOCKER_MODULE=false
WITH_CERTIFICATE_PARAMS=false
MODULE_FOLDER=/var/lib/modules/zabbix
MODULE_FILENAME=zabbix_module_docker.so

HELP_MESSAGE="Usage: ./$(basename $0) [OPTION]
Script for installing and configuration zabbix agent.
Project: zabbix-deployment
Options:
    -b, --bind [ip address]     Set IP address to listen by agent.
    -m, --meta [string]         String to use for auto registration.
    -s, --server [zabbix.local] Set zabbix server to connect by agent. This option is required.
    --hostname [agent.local]    Set agent hostname.
    --enable-docker-module      Download and enable docker module for agent. Is compartible with Template App Docker.
    --with-certificate-params   Enable custom certificate parameters:
                                    1) certificate.enddate[host,port] - returns datetime of expiration the certificate.
                                    2) certificate.endtimestamp[host,port] - returns datetime of expiration the certificate.
    -h, --help                  Show help.

Examples:
    \$ ./$(basename $0) --code secret --server zabbix.local
    \$ ./$(basename $0) -s zabbix.local
"

while [[ $# -gt 0 ]]
do
        key="$1"
        case $key in
                -l|--listen_ip)
                    LISTEN_IP="ListenIP=$2"
                    shift
                ;;
                -m|--meta)
                    META="$2";
                    shift
                ;;
                -s|--server)
                    SERVER="$2";
                    shift
                ;;
                --hostname)
                    HOSTNAME="Hostname=$2";
                    shift
                ;;
                -h|--help)
                    SHOW_HELP=true
                ;;
                --enable-docker-module)
                    ENABLE_DOCKER_MODULE=true
                ;;
                --with-certificate-params)
                    WITH_CERTIFICATE_PARAMS=true
                ;;
                *) # unknown option
                    echo "ERROR! Unknown option. See help."
                    exit 1
                ;;
        esac
shift
done

if [ "${SHOW_HELP}" == "true" ] || [ -z "${SERVER}" ]; then
  echo "${HELP_MESSAGE}"
  exit 0
fi

mkdir -p ${MODULE_FOLDER}

printf "Checking OS compartible with script. "
if [ ! -e "/etc/debian_version" ]; then
  echo "Failed."
  exit 1
fi
echo "Done"

if [ "$(which wget)" == "" ]; then apt-get update &> /dev/null; apt-get install -y wget; fi
printf "Installing zabbix repository. "
wget -q -O /tmp/zabbix-release.deb http://repo.zabbix.com/zabbix/${ZBX_VERSION}/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/pool/main/z/zabbix-release/zabbix-release_${ZBX_VERSION}-1+$(lsb_release -cs)_all.deb
dpkg -i /tmp/zabbix-release.deb > /dev/null
apt-get update > /dev/null
echo "Done."

printf "Installing zabbix-agent. "
apt-get install -y zabbix-agent > /dev/null
echo "Done."

printf "Downloading docker module. "
if [ "${ENABLE_DOCKER_MODULE}" == true ]; then
    docker version &> /dev/null
    if [ "$?" -ne 0 ]; then echo "Failed, docker-engine is not running."; exit 1; fi
    wget -q https://github.com/monitoringartist/zabbix-docker-monitoring/raw/gh-pages/$(lsb_release -is | tr '[:upper:]' '[:lower:]')$(lsb_release -rs | cut -d"." -f1)/${ZBX_VERSION}/${MODULE_FILENAME} \
         -O ${MODULE_FOLDER}/${MODULE_FILENAME}
    usermod -aG docker zabbix
else
    echo "Skipped."
fi

printf "Configuring zabbix agent to work with server: ${SERVER}. "
CONFIG_FILE=/etc/zabbix/zabbix_agentd.d/custom.conf

if [ -e "$(dirname ${CONFIG_FILE})" ]; then

if [ -e "${CONFIG_FILE}" ]; then cp ${CONFIG_FILE} ${CONFIG_FILE}.backup; fi
cat << EOF > ${CONFIG_FILE}
Server=${SERVER}
${LISTEN_IP}
${HOSTNAME}
LoadModulePath=${MODULE_FOLDER}
EOF

if [ ! -z "${META}" ]; then
cat << EOF >> ${CONFIG_FILE}
ServerActive=${SERVER}
HostMetadata=${META}
EOF
fi

if [ "${ENABLE_DOCKER_MODULE}" == true ]; then
cat << EOF >> ${CONFIG_FILE}
LoadModule=${MODULE_FILENAME}
EOF
fi

if [ "${WITH_CERTIFICATE_PARAMS}" == true ]; then
cat << EOF >> ${CONFIG_FILE}
UserParameter=certificate.endtimestamp[*],date --date "\$(echo | openssl s_client -showcerts -servername \$1 -connect \$1:\$2 2>/dev/null | openssl x509 -inform pem -noout -enddate | cut -d= -f2)" +%s
UserParameter=certificate.enddate[*],date --date "\$(echo | openssl s_client -showcerts -servername \$1 -connect \$1:\$2 2>/dev/null | openssl x509 -inform pem -noout -enddate | cut -d= -f2)"
EOF
fi

echo "Done."

else
  echo "Failed."
  exit 1
fi

printf "Checking zabbix agent service is enabled. "
update-rc.d zabbix-agent enable
echo "Done"

printf "Restarting zabbix agent. "
service zabbix-agent restart > /dev/null
echo "Done."

printf "Removing dangling data. "
rm -f /tmp/zabbix-release.deb
echo "Done."
