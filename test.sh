msg_out(){
	printf "\n*** $*\n" > /dev/stdout
}

err_out(){
	printf "\nE: $*\n" > /dev/stderr
}

wrn_out(){
	printf "\nW: $*\n" > /dev/stderr
}

err_exit(){
	err_out "$*"
	exit 1
}

get_yn(){
	#$1: msg
	#$2: timeout
	local msg="
	=== $(printf "$1")"
	msg=$(echo "$msg" |sed -e 's/^[[:blank:]]*//')
	local yn
    local timeout="$2"
	if [ "$2" = "" ]; then
		read -p "$msg" yn >/dev/null
	else
	    if ! echo "$timeout" |grep -E '^[0-9]+$' >/dev/null; then
	        err_exit "invalid timeout value: $timeout"
	    fi
		read -t "$2" -p "$msg" yn >/dev/null
	fi
	if [ "$yn" = y ]; then
		echo y > /dev/stdout
    else
        echo "$yn" > /dev/stdout
	fi
}

yn=$(get_yn "fljdslfjlsd: " 10)
echo "$yn"
