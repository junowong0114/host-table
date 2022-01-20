#!/bin/bash
set -e
set -o pipefail

usage() {
  echo "Usage:"
  printf "hosts.sh [-f CONFIG_FILE] \n\n"
  echo "Description:"
  echo "-f, CONFIG_FILE       The path of hosts.yml [default \"~/.hosts/hosts.yml\"]"
  echo "-l                    List current host table settings for hostnames in CONFIG_FILE"
  exit -1
}

CONFIG_FILE=~/.hosts/hosts.yml
HOST_TABLE_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"

list() {
    declare -a HOSTNAMES=($(cat $CONFIG_FILE | grep -e '^[^ ].*' | perl -pe "s|(.*):|\1|"))

    for TARGET in "${HOSTNAMES[@]}"; do
        IP=$(cat $HOST_TABLE_FILE | grep "$TARGET" | perl -pe "s|((?:[0-9]+\.){3}[0-9]+) (.*)|\1|") || true
        if [[ $IP ]]; then
            VALUE="$IP ($(cat $CONFIG_FILE | grep $IP | perl -pe "s| *- *['\"]*(.*):((?:[0-9]+\.){3}[0-9]+)['\"]*|\1|"))"
        else
            VALUE=""
        fi
        echo "$TARGET: $VALUE"
    done
    exit 0
}

while getopts ':f:hl' OPT; do
  case $OPT in
    f) CONFIG_FILE=$OPTARG;;
    h) usage;;
    l) list;;
    \:) printf "Error: Argument missing from -%s option\n\n" $OPTARG
        usage
        exit 2
        ;;
    \?) printf "Error: Unknown option: -%s\n\n" $OPTARG
        usage
        exit 2
        ;;
  esac >&2
done
shift $(($OPTIND - 1))

declare -a HOSTNAMES
HOSTNAMES=($(cat $CONFIG_FILE | grep -e '^[^ ].*' | perl -pe "s|(.*):|\1|"))

echo "Select a hostname to be configured:"
declare -a OPTIONS
OPTIONS+=("Disable host table setting")
ACTIVE=false

while [[ ! $TARGET_HOSTNAME ]]; do
    select TARGET_HOSTNAME in ${HOSTNAMES[@]}; do
        if [[ ! $TARGET_HOSTNAME ]]; then
            printf "\nInvalid selection, try again:\n"
            break
        fi

        while read line; do
            if [[ $ACTIVE == 'true' ]]; then
                if [[ ! $line =~ ^-.*$ ]]; then
                    break
                fi;

                desc=$(echo $line | perl -pe "s|- [\"']*(.*):((?:[0-9]+\.){3}[0-9]+)[\"']*|\1|")
                ip=$(echo $line | perl -pe "s|- [\"']*(.*):((?:[0-9]+\.){3}[0-9]+)[\"']*|\2|")

                OPTIONS+=("$ip ($desc)")
            fi

            if [[ $line == $TARGET_HOSTNAME: ]]; then
                ACTIVE=true
            fi
        done < $CONFIG_FILE
        break
    done
done

printf "\nSelect an ip to be set to $TARGET_HOSTNAME:\n"
while [[ ! $OPTION ]]; do
    select OPTION in "${OPTIONS[@]}"; do
        if [[ ! $OPTION ]]; then
            printf "\nInvalid selection, try again:\n"
            break
        fi

        if [[ $OPTION == 'Disable host table setting' ]]; then
            sed -i "/.*$TARGET_HOSTNAME.*/d" $HOST_TABLE_FILE
            printf "\nDisabled host table settings to $TARGET_HOSTNAME.\n"
            break
        fi

        IP=$(echo $OPTION | perl -pe "s|((?:[0-9]+\.){3}[0-9]+).*|\1|")
        if [[ $(cat $HOST_TABLE_FILE | grep $TARGET_HOSTNAME) ]]; then
            perl -i -pe "s|.*$TARGET_HOSTNAME.*|$IP $TARGET_HOSTNAME|" $HOST_TABLE_FILE
        else
            echo "$IP $TARGET_HOSTNAME" >> $HOST_TABLE_FILE
        fi;
        printf "\nSuccessfully set $TARGET_HOSTNAME to $IP.\n"
        break
    done
done
