#!/bin/sh

# application API
# --------------------
dest_ip=$(echo $1 | sed 's/::ffff://'); #IP (nnn.nnn.nnn.nnn notation or hostname)
dest_port=$2;#port (decimal, host byte order)

# you should configure the following variables on the monitor configuration or enable these lines to pass the arguments on the command line
# I just found that it's easier to do it through variables as it's more clear to review them
#community=$3; #community 
#oid=$4; #oid
#expected_val=$5; #expected value (for setting monitor UP)

# configurations
# -------------------
pid=$$
timeout=2
up=UP
down=DOWN
loglevel=1
pidfile="/var/run/generic-snmp-monitor-${dest_ip}-${dest_port}-${community}-${oid}.pid"
log_file=/var/log/generic-snmp-monitor-${dest_ip}.log

function write_log ()
{
echo "$(date +%Y-%m-%d) $(date +%T) ${pid} $*" >> $log_file
}

function init ()
{
write_log "=== monitor started ==="
if [ -f $pidfile ]; then
write_log "${pidfile} exist"
kill -9 `cat $pidfile` > /dev/null 2>&1
err=$?
write_log "PID:$(cat $pidfile) killed, error code:${err}"
fi
echo ${pid} > $pidfile
write_log "setting ${pidfile} with pid: ${pid}"

verify_param "dest_ip" "${dest_ip}"
verify_param "dest_port" "${dest_port}"
verify_param "community" "${community}"
verify_param "oid" "${oid}"
verify_param "expected_val" "${expected_val}"
}

function verify_param ()
{
name=$1; val=$2;
if [ "${name}" = "" ] || [ "${val}" = "" ]; then
on_error "name:"${name}" or value:"${val}" not set"
fi
#else
#  write_log "name:${name} val:${val}"
#fi
}

function run_snmp_test ()
{
cmd="snmpget -O qv -t ${timeout} -v2c -c ${community} ${dest_ip}:161 ${oid}"

write_log "cmd=${cmd}"
result=$(${cmd})
err=$?

if [ ${err} -ne 0 ]; then
on_error "snmpget existed with error code:${err}"
fi 

if [ "${result}" -le "${expected_val}" ]; then
  write_log "OK - RESULT:${result} as expected"
  response ${up}
else
  write_log "FAIL - RESULT:${result} !le ${expected_val}"
response ${down}
fi
}

function response ()
{
status=$1
write_log "response status:${status}"
if [ "${status}" = "${up}" ]; then
echo ${status}
fi
}

function cleanup ()
{
write_log "deleting ${pidfile}"
rm -f ${pidfile} >/dev/null
}

function on_error ()
{
write_log "ERROR: $1"
response ${down};
cleanup;
write_log "=== monitor aborted ==="
exit -1
}

function main ()
{
init;
run_snmp_test;
cleanup;
write_log "=== monitor ended ==="
exit 0
}
main;
