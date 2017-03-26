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


get_prop_val(){
	prop="$1"
	cf="$2"
	grep -isoP "(?<=^$prop=).*" "$cf" > /dev/stdout
}

chk_conf_prop(){
	local prop="$1"
	local cf="$2"
	if grep -isq "^[[:blank:]]*$prop=" "$cf";then
		return 0
	else
		return 1
	fi
}


update_prop_val(){
	local prop="$1"
	local val="$2"
	local cf="$3"
	local h="$4"
	if chk_conf_prop "$prop" "$cf"; then
		# sed -E -i.bak "s/^[[:blank:]]*(RetainHome=).*/\1$val/I" "$cf"
		echo "$(awk "BEGIN{IGNORECASE=1} {sub(/^[[:blank:]]*$prop=.*$/,\"$prop=$val\");print}" "$cf")" > "$cf"
	else
		printf "\n#$h\n$prop=$val\n" >> "$cf"
	fi
}

export a=uiouio

fun(){
	b=a
	echo ${!b}
}
fun
