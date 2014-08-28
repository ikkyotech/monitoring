#!/bin/bash

#
#  ! Constants ""
#
export ETC_TD="/etc/td-agent"
export ETC_TD_AGENT="$ETC_TD/td-agent.conf"
export ETC_TD_CONF="$ETC_TD/conf.d"
export TMP_FOLDER="/tmp/ikkyotech"
export NEW_RELIC_LICENSE_FOLDER="/etc/newrelic"
export NEW_RELIC_LICENSE_PATH="$NEW_RELIC_LICENSE_FOLDER/.key"

#
#  ! Variable check methods !
#
makeBool() {
    VALUE=${!1}
    if [[ "$VALUE" == "True" || "$VALUE" == "TRUE" || "$VALUE" == "true" ]]; then
        Value="true"
    else
        Value="false"
    fi
    export $1=$VALUE  
}

default() {
    if [ -z "${!1}" ]; then
        export $1=$2
    fi
}

parseHosts() {
    RAW="${!1}"
    DEFAULT_PORT=$2
    result=""
    if [ ! -z "$RAW" ]; then
        IFS=''
        while read -d ";" RAW_HOST; do
            if [ ! -z "$RAW_HOST" ]; then
                host=""
                port=$DEFAULT_PORT
                i=0
                while read -d ":" PART; do
                    if [ ! -z "$PART" ]; then
                        if [[ $i -eq "0" ]]; then
                            host="$PART"
                        elif [[ $i -eq "1" ]]; then
                            port="$PART"
                        fi
                        i=$(( $i + 1 ))
                    fi
                done <<< "$RAW_HOST:"
                result+="\"'$host' '$port'\" "
            fi
        done <<< "$RAW;"
    fi
    script="export $1=\"\${result[@]}\""
    eval $script
}

#
#  ! Header methods !
#
export HEADER_CNT=0
export HEADER_TXT="MONITORING"
export HEADER_TXT_CNT=${#HEADER_TXT} 

headerSingleLine() {
    if   [[ $HEADER_CNT -lt "1" || $HEADER_CNT -gt $(( $HEADER_TXT_CNT + 2 )) ]]; then echo "///////  $1";
    elif [[ $HEADER_CNT -lt "2" || $HEADER_CNT -gt $(( $HEADER_TXT_CNT + 1 )) ]]; then echo "//   //  $1";
    else
        START=$(( $HEADER_CNT - 2 ))
        END=$(( $START + 1 ))
        CHAR=${HEADER_TXT:$START:1}
        echo "// $CHAR //  $1"
    fi
    HEADER_CNT=$(( $HEADER_CNT + 1 ))
}

headerLine() {
    IFS=''
    while read line; do
        headerSingleLine "$line"
    done <<< "$1"
}

header() {
    echo "" # Empty line before starting with the header
    headerLine "$1"
}

headerSection() {
    headerLine "[$1]"
    
    PATTERN_NAME=$2
    PATTERN=${!PATTERN_NAME}
    if [[ -z "$PATTERN" ]]; then
        headerLine "    Not active (missing $PATTERN_NAME)"
    else
        args=("$@")
        length=${#args[@]}  
        for (( i=1;i<$length;i++)); do
            FIELD_NAME=${args[${i}]} 
            headerLine "    $FIELD_NAME: ${!FIELD_NAME}"
        done
    fi
    headerLine ""
}

headerOptional() { for i; do headerLine "- ($i): ${!i}"; done; }
headerEnd() {
    headerLine ""; echo "" ;
}

#
#  ! Prepare all variables !
#

default "HOST" "https://ikkyotech.github.io/monitoring"
makeBool "VERBOSE"
default "FLUENTD_TCP_PORT" "24224"
default "S3_PREFIX" ""
default "S3_KEY_FORMAT" "%{hostname}-%{time_slice}_%{index}.%{file_extension}"
default "S3_REGION" "us-east-1"
default "S3_BUFFER_PATH" "/var/tmp/fluent/s3"
default "S3_TIME_SLICE_FORMAT" "%Y%m%d-%H"
default "S3_TIME_SLICE_WAIT" '10m'
default "TD_BUFFER_PATH" '/var/log/td-agent/buffer/td'
default "DEBUG_DOMAIN" "127.0.0.1"
default "DEBUG_PORT" "24230"
default "AG_FLUSH_INTERVAL" "60s"
parseHosts "AG_TARGET_HOSTS" $FLUENTD_TCP_PORT

#
#  ! Render the Header !
#

header "
Ikkyotech's monitoring setup.

Install services to monitor a server instance, depending on the configuration
that you passed in via variables.

Specifically:
  - FluentD for logging data from client applications
  - New Relic server monitoring and to enable newrelic for your client applications

More under: $HOST
"

if [[ $VERBOSE == "true" ]]; then
    headerSection "New Relic" \
        "NEW_RELIC_LICENSE"
    headerSection "FluentD (Debugging)" \
        "DEBUG_PATTERN" "DEBUG_DOMAIN" "DEBUG_PORT"
    headerSection "FluentD -> Treasure Data" \
        "TD_PATTERN" "TD_API_KEY" "TD_BUFFER_PATH"
    headerSection "FluentD -> Aggregator" \
        "AG_PATTERN" "AG_TARGET_HOSTS" "AG_FLUSH_INTERVAL"
    headerSection "FluentD -> S3" \
        "S3_PATTERN" "AWS_KEY_ID" "AWS_SECRET_KEY" "S3_BUCKET" "S3_PREFIX" "S3_KEY_FORMAT" \
        "S3_REGION" "S3_BUFFER_PATH" "S3_TIME_SLICE_FORMAT" "S3_TIME_SLICE_WAIT"
    headerSection "FluentD <- TCP" \
        "FLUENTD_TCP_PORT"
    headerSection "FluentD <- HTTP" \
        "FLUENTD_HTTP_PORT"
fi
headerOptional "VERBOSE"
headerEnd

# With sudo you loose all method definitions that we defined before so I defined
# the step methods after this line

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "1.) Making sure that the script is run in _sudo_ mode ..."
    sudo -Es su
else
    export CNT=1
fi

if [ -z "$CNT" ]; then
    if [[ $(/usr/bin/id -u) -ne 0 ]]; then
        echo "Error: I have to install system services and I need to be accessing *root* folders. (sudo missing)"
        exit
    fi
    echo "    ... done."
    export CNT=2
fi

# Allowing bash to fail gracefully
set -e

if [[ "$VERBOSE" == "true" ]]; then
    exec 3>&1
else
    exec 3>/dev/null
fi

#
#  ! Methods to run the various steps of the setup !
#
step() { echo "$CNT.) $1 ..."; CNT=$((CNT+1)); }
end()  { echo "    ... done."; }
log()  { if [ "$VERBOSE" == "true" ]; then
         echo "      - $@"; fi; }
warn() { echo "      Warning: $@"; }
mkdirPS() {
    if [[ ! -d "$@" ]]; then
        log "Creating folder '$@'"
        mkdir -p "$@"
    fi
}

# The td steps are very similar in a sense that all create a
# file based on a condition, that should
step_td() {
    CONF_PATH=$ETC_TD_CONF/$1-$4.conf
    if [[ ! -z "$2" ]]; then
        step "Adding FluentD configuration to $5 '$1'"
            if [ ! -d "$ETC_TD_CONF" ]; then
                mkdirPS $ETC_TD_CONF
            fi
            log "Writing configuration to $CONF_PATH"
            echo "$3" > $CONF_PATH
        end
    else
        if [ -f $CONF_PATH ]; then
            step "Removing FluentD configuration to $5 '$1'"
                rm -f $CONF_PATH
            end
        fi
    fi
}

step_td_in() {
    step_td "$1" "$2" "
<source>
$3
</source>" "in" "receive from"
}

step_td_out() {
    step_td "$1" "$2" "
<match $2>
$3
</match>" "out" "send to"
}

td_add_servers() {
    i=0
    eval "hosts=($@)"
    for host in "${hosts[@]}"; do
        if [[ ! -z "$host" ]]; then
            script="td_add_server $host $i"
            eval "$script"
            i=$(( $i + 1 ))
        fi
    done
}

td_add_server() {
    if [[ $3 -eq 0 ]]; then
        standby=""
    else
        standby="standby"
    fi
    echo "
<server>
    host $1
    port $2
    $standby
</server>"
}

isOS() {
    return $(cat /proc/version | grep "@1" -c) != "0"
}

available() {
    command -v "$1" >/dev/null 2>&1 || return false;
    return true;
}

require() {
    available "$1" || { echo >&2 "Error: Missing command '$1'. $2 Aborting."; exit 1; }
}

#
#   Trapping all the steps. This way if an error occurs no strange error messages are displayed.
#
f() {

    if [[ "$OS" != "None" ]]; then
        if [[ -z "$OS" ]]; then
            step "Identifing the Operating System"
                if [[ isOS "Red Hat" ]]; then
                  export OS="RedHat"
                elif [[ isOS "Ubuntu" || isOS "Debian" ]]; then
                  export OS="Debian"
                else
                  echo "Error: Can't identify the Operating System."
                  exit 1;
                fi
            end
        fi
    
        if [ ! -d "$TMP_FOLDER" ]; then
            step "Creating temporary folder: $TMP_FOLDER"
                mkdirPS $TMP_FOLDER
            end
        fi
    
        step "Loading OS($OS) specific code"
    
            OS_MONIT_FILE=$OS
            OS_MONIT_URL=$HOST/$OS_MONIT_FILE
            OS_MONIT_PATH=$TMP_FOLDER/$OS_MONIT_FILE
    
            log "Fetching file from '$OS_MONIT_URL' to '$OS_MONIT_PATH'"
            curl -fsL $OS_MONIT_URL > $OS_MONIT_PATH
            source $OS_MONIT_PATH
        end
    
        # Method loaded from the OS specific file!
        install_monitor

        if [[ ! -z "$NEW_RELIC_LICENSE" ]]; then
            step "Setting up newrelic server script to monitor the servers health."
                log "Configure & start the Server Monitor daemon"
                log "Add license key to config file: (See /etc/newrelic/nrsysmond.cfg for other config options)"
                nrsysmond-config --set license_key=$NEW_RELIC_LICENSE >&3
                
                log "Start the daemon:"
                /etc/init.d/newrelic-sysmond restart >&3
            end
        fi
    fi

    if [[ ! -z "$NEW_RELIC_LICENSE" ]]; then
        step "Storing newrelic key to $NEW_RELIC_LICENSE_PATH with chmod 750"
            mkdirPS $NEW_RELIC_LICENSE_FOLDER
            echo "$NEW_RELIC_LICENSE" > "$NEW_RELIC_LICENSE_PATH"
            chmod 750 "$NEW_RELIC_LICENSE_PATH"
            chown newrelic:daemon "$NEW_RELIC_LICENSE_PATH" 2>&3
        end
    fi

    step "Writing main fluent-d configuration to $ETC_TD_AGENT"
        mkdirPS "$ETC_TD"
        log "Adding $ETC_TD_CONF/*.conf as lookup for additional configuration"
        TD_CONF="

include conf.d/*.conf"

        log "Adding default source lookup to port $FLUENTD_TCP_PORT"
        TD_CONF="$TD_CONF
<source>
  type forward
  port $FLUENTD_TCP_PORT
</source>
"

        if [[ ! -z "$DEBUG_PATTERN" ]]; then
            log "Adding debug configuration for $DEBUG_PATTERN"

            TD_CONF="$TD_CONF
<match $DEBUG_PATTERN>
  type stdout
</match>

<source>
  type debug_agent
  bind $DEBUG_DOMAIN
  port $DEBUG_PORT
</source>"
        fi

        echo "$TD_CONF" > $ETC_TD_AGENT
    end

    AG_CONF="
type forward"

    AG_CONF="$AG_CONF$(td_add_servers $AG_TARGET_HOSTS)"

    AG_CONF="$AG_CONF
# use longer flush_interval to reduce CPU usage.
# note that this is a trade-off against latency.
flush_interval $AG_FLUSH_INTERVAL
"

    step_td_out "ag" "$AG_PATTERN" $AG_CONF

    step_td_out "td" "$TD_PATTERN"  "
type tdlog
apikey $TD_API_KEY

auto_create_table
buffer_type file
buffer_path $TD_BUFFER_PATH"

    step_td_out "s3" "$S3_PATTERN" "
type s3
aws_key_id $AWS_KEY_ID
aws_sec_key $AWS_SECRET_KEY
s3_bucket $S3_BUCKET
s3_endpoint s3-$S3_REGION.amazonaws.com
s3_object_key_format $S3_PREFIX$S3_KEY_FORMAT

buffer_path $S3_BUFFER_PATH
time_slice_format $S3_TIME_SLICE_FORMAT
time_slice_wait $S3_TIME_SLICE_WAIT
utc true"

    step_td_in "http" "$FLUENTD_HTTP_PORT" "
type http
port $FLUENTD_HTTP_PORT"

    if [ "$OS" != "None" ]; then
        step "Restarting td-agent"
            service td-agent restart >&3
        end
    fi

    step "Clearing Temp folder $TMP_FOLDER"
        # Always clear the temp folder
        rm -rf $TMP_FOLDER
    end
}
trap f EXIT

false