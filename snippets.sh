#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR_SNIPPETS="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

function find_all_ips_dir () {
    DIR="$1"
    if [ -z "$DIR" ]; then
        echo "Specify DIR as first argument. Exit."
        exit 1
    fi
    FPATTERN="$2"
    if [ -z "$FPATTERN" ]; then
        echo "Specify FPATTERN as first argument. Exit."
        exit 1
    fi
    GREP_PATTERN="$3"
    REGEX="(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
    if [ -n "$GREP_PATTERN" ]; then
        find "$DIR" -name "$FPATTERN" -type f | $GREP_PATTERN | while read -r x; do
            grep -hEo $REGEX "$x" | grep -Ev 'Binary file.*matches'
        done
    else
        find "$DIR" -name "$FPATTERN" -type f -exec grep -hEo $REGEX {} + | grep -Ev 'Binary file.*matches'
    fi
}


function find_all_ips_file () {
    REGEX="(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
    grep -hEo $REGEX "$1" | grep -Ev 'Binary file.*matches'
}

function check_ip_is_local () {
    LOCAL=$(ip a | grep inet | grep -w "$1")
    if [ -n "$LOCAL" ]; then
        echo "IP $1 is local"
        return 1
    else
        echo "IP $1 is NOT local"
        return 0
    fi
}

function date_hm () {
  date +'%d_%m_%Y-%H_%M'
}

function date_hmh () {
  date +'%d-%m-%Y %H:%M:%S'
}


function datetime () {
  date +'%d-%m-%Y %H:%M'
}

function date_ymdhms () {
  date +'%Y-%m-%d_%H_%M_%S'
}


function date_dmy () {
  date +'%d_%m_%Y'
}

function date_mdy () {
  date +'%m_%d_%Y'
}

function vm_wait_till_shut_down () {
  for i in {1..600}; do
    STATE=$(virsh domstate "$1")
    if [ "$STATE" != "running" ]; then
      sleep 1
      return 0
    fi
    sleep 1
  done
  return 1
}


function vm_shutdown_wait () {
  VM="$1"
  STATE=$(virsh domstate "$VM")
  if [ "$STATE" == "running" ]; then
      virsh shutdown "$VM"
  fi
  vm_wait_till_shut_down "$VM"
  return $?
}


function vm_get_disks () {
  virsh domblklist "$1" | grep '/' | egrep -v '\.iso$' | awk '{print $2;}'
}

function check_required_tools () {
  TOOLS=( awk dd pigz virsh )
  for TOOL in "${TOOLS[@]}"; do
    PRESENT=$(which "$TOOL")
    if [ -z "$PRESENT" ];then
      echo "Required tool: $TOOL not in PATH. Exit."
      exit 1
    fi
  done
}

function check_virt_what () {
  TOOLS=( virt-what )
  for TOOL in "${TOOLS[@]}"; do
    PRESENT=$(which "$TOOL")
    if [ -z "$PRESENT" ];then
      echo "Required tool: $TOOL not in PATH. Exit."
      exit 1
    fi
  done
}

# Send test email
function send_email () {
  # email host subject body attach
  if [ -z "$1" ]; then
    echo "Usage:"
    echo "send_email EMAIL HOST SUBJECT BODY(opt) ATTACHMENT(opt)"
  fi
  TMPF="/tmp/$$.se"
  EMAIL="$1"
  HOST="$2"
  echo "set -x" >> "$TMPF"
  echo -n "swaks -4 -t \"$EMAIL\" " >> "$TMPF"
  echo -n " -s $HOST " >> "$TMPF"
  if [ -n "$3" ]; then
    echo -n " --header \"Subject: $3\" " >> "$TMPF"
  fi
  if [ -n "$4" ]; then
    echo -n " --body \"$4\" " >> "$TMPF"
  fi
  if [ -n "$5" ]; then
    echo -n " --attach \"$5\" " >> "$TMPF"
  fi
  chmod 700 "$TMPF"
  "$TMPF"
  rm -f "$TMPF"
}

# Send test email to all ALERT_EMAIL_HOSTS (defined in /etc/local/settings.sh)
function email_alert () {
  # subject body attach
  for HOST in "${ALERT_EMAIL_HOSTS[@]}"; do
    send_email "$ALERT_EMAIL" "$HOST" "$1" "$2" "$3"
  done
}

function test_arg () {
	if [ -z "$1" ]; then
		echo "Param $2 empty. Exit."
    if [ -n "$3" ]; then
      echo
      echo "Usage:"
      echo "  $3"
    fi
		exit 1
	fi
}

function confirm () {
  read -r -p "Are you sure? [y/N] " RESPONSE
  if [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])+$ ]]
  then
      return 0
  else
      return 1
  fi
}

function join_by () {
  # use: join_by , "${FOO[@]}"
  local IFS="$1"
  shift
   echo "$*"
}

# List users belonging to the group.
function group_users () {
	if [ -z "$1" ]; then
		echo "Specify group name as first argument."
		exit 1
	fi

	getent passwd | sort | while IFS=: read name trash
	do
			groups $name 2>/dev/null | cut -f2 -d: | grep -i -q -w "$1" && echo $name
	done
}

function umount_loop0_devices {
  mount | grep /dev/loop0 | while read x; do
    DEV=$(echo "$x" | awk '{print $1;}')
    umount "$DEV"
  done
  umount /dev/loop0 &>/dev/null
  losetup -d /dev/loop0 &>/dev/null
}

# Wake workstation (dialog)
function ws () {
	TMP1=/tmp/$$.1
	TMP2=/tmp/$$.2
	/usr/local/bin/list_ws.sh | egrep -v '^$'  | sort | awk '{print NR " " $0;}' | sort -n > "$TMP1"
	dialog --clear --menu "Select workstation to WAKE:" 24 70 $(wc -l "$TMP1" | cut -d " " -f 1)  $(cat "$TMP1") 2> "$TMP2"
  NUM=$(cat "$TMP2")
  if [ -n "$NUM" ]; then
      WS=$(sed "${NUM}q;d" "$TMP1" | awk '{print $2;}')
      rm -f "$TMP1"
      rm -f "$TMP2"
      set -x
      wake_ws.sh "$WS"
      set +x
  fi
  rm -f "$TMP1"
  rm -f "$TMP2"
}

# Select hostfile for hss (dialog)
function hs () {
    BASEDIR=/usr/local/etc
	TMP1=/tmp/$$.1
	TMP2=/tmp/$$.2
	if [ -d /usr/local/etc ]; then
		find /usr/local/etc -name "*.hostfile" -printf "%f\n" | sort | awk '{print NR " " $0;}' | sort -n > "$TMP1"
	else
		find ./ -name "*.hostfile" -printf "%f\n" | sort | awk '{print NR " " $0;}' | sort -n > "$TMP1"
	fi
	if [ -f ~/.config/shed_scripts/hs.last ]; then
		whiptail --clear --default-item $(cat ~/.config/shed_scripts/hs.last) --menu "Select hss hostfile:" 24 70 $(wc -l "$TMP1" | cut -d " " -f 1)  $(cat "$TMP1") 2> "$TMP2"
	else
		whiptail --clear --menu "Select hss hostfile:" 24 70 $(wc -l "$TMP1" | cut -d " " -f 1)  $(cat "$TMP1") 2> "$TMP2"
	fi
    NUM=$(cat "$TMP2")
    if [ -n "$NUM" ]; then
		shed_config_mkdirp.sh
		echo "$NUM" > ~/.config/shed_scripts/hs.last
        HOSTFILE=$(sed "${NUM}q;d" "$TMP1" | awk '{print $2;}')
        rm -f "$TMP1"
        rm -f "$TMP2"
        hss -c '-C -x' -f "$BASEDIR/$HOSTFILE"
    fi
}


# Email root using local 'sendmail' command
function email_root () {
    HOST=$(hostname --fqdn)
    sendmail root@"$HOST" <<EOF
Subject: $1 ($SCRIPTNAME)

$2

EOF
}


# Notify zabbix_sender about a problem, use key "misc", problem description as first argument
function problem_notify_misc () {
  PROBLEM="$1"
  if [ -z "$PROBLEM" ]; then
    echo "Specify problem description as first argument."
    return 1
  fi
  "$SCRIPTDIR_SNIPPETS"/monitoring/notify_zabbix_sender.sh "misc" "$PROBLEM"
  return $?
}

# Notify zabbix_sender about a problem, use key "misc", problem description as first argument, also send email
function problem_notify_misc_email () {
  PROBLEM="$1"
  if [ -z "$PROBLEM" ]; then
    echo "Specify problem description as first argument."
    return 1
  fi
  "$SCRIPTDIR_SNIPPETS"/monitoring/notify_zabbix_sender.sh "misc" "$PROBLEM"
  "$SCRIPTDIR_SNIPPETS"/email_alert.sh "$PROBLEM"
  return $?
}


function problem_notify_misc_exit () {
  PROBLEM="$1"
  if [ -z "$PROBLEM" ]; then
    echo "Specify problem description as first argument."
    return 1
  fi
  "$SCRIPTDIR_SNIPPETS"/monitoring/notify_zabbix_sender.sh "misc" "$PROBLEM"
  exit 1
}

# Conditional notify zabbix_sender about a problem, use key "misc", conditional value as first argument and problem description as second argument
function cond_problem_notify_misc () {
  COND="$1"
  PROBLEM="$2"
  if [ -z "$COND" ]; then
    echo "Specify condition (int) value as first argument."
    return 1
  fi
  if [ -z "$PROBLEM" ]; then
    echo "Specify problem description as second argument."
    return 1
  fi
  if [ "$COND" != "0" ]; then
    problem_notify_misc "$PROBLEM"
    return $?
  fi
}


# Conditional notify zabbix_sender about a problem, use key "misc" if 3rd argument non-empty, otherwise use it as specified key; conditional value as first argument and problem description as second argument
function cond_problem_notify_key () {
  COND="$1"
  KEY="$2"
  PROBLEM="$3"
  if [ -z "$COND" ]; then
    echo "Specify condition value as first argument."
    return 1
  fi
  if [ -z "$KEY" ]; then
    echo "Specify key as second argument."
    return 1
  fi
  if [ -z "$PROBLEM" ]; then
    echo "Specify problem description as third argument."
    return 1
  fi
  if [ "$COND" != "0" ]; then
    "$SCRIPTDIR_SNIPPETS"/monitoring/notify_zabbix_sender.sh "$KEY" "$PROBLEM"
    return $?
  fi
}

function problem_notify_key () {
  KEY="$1"
  PROBLEM="$2"
  if [ -z "$KEY" ]; then
    echo "Specify key as first argument."
    return 1
  fi
  if [ -z "$PROBLEM" ]; then
    echo "Specify problem description as second argument."
    return 1
  fi
  "$SCRIPTDIR_SNIPPETS"/monitoring/notify_zabbix_sender.sh "$KEY" "$PROBLEM"
  return $?
}

testn () {

    if [ -z "$1" ]; then

        echo "Param $2 empty. Aborting"

        echo "Usage: $0 NAME MAC TYPE"

        exit 1

    fi

}


function uncomment_hashed_line () {
	if [ -z "$1" ]; then
		echo "Specify file path as first arg"
		return
	fi
	if [ ! -f "$1" ]; then
		echo "File $1 not found"
		return
	fi
	if [ -z "$2" ]; then
		echo "Specify word to search for as second arg"
		return
	fi
	UNCOMMENT="$2"
	sed -i "s/^\s*#\s*\($UNCOMMENT\)/\1/g" "$1"
}

function ip2revdns () {
    REVIP=$(echo "$1" | awk -F. '{printf("%s.%s.%s.%s", $4, $3, $2, $1);}')
    REVDOM="$2"
    if [ -z "$REVDOM" ]; then
        REVDOM='bl.blocklist.de'
    fi
    echo "${REVIP}.${REVDOM}"
}

function blocklist_de_check () {
    IP="$1"
    if [ -z "$IP" ]; then
		echo "Specify IP to check at bl.blocklist.de as first arg"
		return
	fi
    host -t any $(ip2revdns "$IP") 8.8.8.8 | grep -v NXDOMAIN | egrep 'blocklist.de has address|blocklist.de descriptive text'
}


function estatus_notify_zabbix () {
    MSG="Failure of script ${SCRIPTDIR}/${SCRIPTNAME}"
    if [ -n "$1" ]; then
        MSG="$1"
    fi
    echo "$MSG"
    problem_notify_misc "$MSG"
    exit 1
}

function check_pidfile_stale () {
    LOCKFILE="$1"
    MAXAGE="$2"
    [ -z "$LOCKFILE" ] && echo "Specify LOCKFILE as first argument" && return 6
    [ -z "$MAXAGE" ] && echo "Specify MAXAGE as second argument" && return 6
    [ ! -f "$LOCKFILE" ] && echo "Lockfile $LOCKFILE does not exist" && return 0
    MTIME_EPOCH=$(stat -c '%Y' "$LOCKFILE")
    NOW_EPOCH=$(date +'%s')
    # echo "NOW_EPOCH $NOW_EPOCH"
    # echo "MTIME_EPOCH $MTIME_EPOCH"
    # echo "MAXAGE $MAXAGE"
    if (( $NOW_EPOCH - $MTIME_EPOCH > $MAXAGE )); then
        return 2
    fi
    return 1
}


function uncommented () {
    FNAME="$1"
    [ -z "$FNAME" ] && echo "Specify filename" && return 1
    egrep -v '^\s*#' "$FNAME" | tr -s '\n\n'
}


function uncommented_semicolon () {
    FNAME="$1"
    [ -z "$FNAME" ] && echo "Specify filename" && return 1
    egrep -v '^\s*;' "$FNAME" | tr -s '\n\n'
}


function drbd_primary_check () {
    PRIMARY=$(grep 'cs:' /proc/drbd | awk -F: '{print $4;}' | awk -F/ '{print $1;}')
    [ -n "$PRIMARY" ] && return 1
    return 0
}

# cat which file
function catwhich {
    W=$(which "$1")
    echo "======================================================"
    echo "cat $W"
    echo "======================================================"
    cat "$W"
}
