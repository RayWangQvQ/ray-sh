###
# @Author: Ray zai7lou@outlook.com
# @Date: 2023-02-11 15:04:29
 # @LastEditors: Ray zai7lou@outlook.com
 # @LastEditTime: 2023-02-11 20:17:36
# @FilePath: https://github.com/RayWangQvQ/ray-sh/blob/main/ray-inf.sh
# @Description: Infrastracture of shell
###

verbose=false

invocation='echo "" && say_verbose "Calling: ${yellow:-}${FUNCNAME[0]} ${green:-}$*${normal:-}"'

if [ -t 1 ] && command -v tput >/dev/null; then
    ncolors=$(tput colors || echo 0)
    if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
        bold="$(tput bold || echo)"
        normal="$(tput sgr0 || echo)"
        black="$(tput setaf 0 || echo)"
        red="$(tput setaf 1 || echo)"
        green="$(tput setaf 2 || echo)"
        yellow="$(tput setaf 3 || echo)"
        blue="$(tput setaf 4 || echo)"
        magenta="$(tput setaf 5 || echo)"
        cyan="$(tput setaf 6 || echo)"
        white="$(tput setaf 7 || echo)"
    fi
fi

say_verbose() {
    if [ "$verbose" = true ]; then
        # using stream 3 (defined in the beginning) to not interfere with stdout of functions
        # which may be used as return value
        printf "%b\n" "${cyan:-}$(date "+%Y-%m-%d %H:%M:%S")[VER]:${normal:-} $1" >&3
    fi
}

say_info() {
    printf "%b\n" "${green:-}$(date "+%Y-%m-%d %H:%M:%S")[INF]:$1${normal:-}" >&2
}

say_warning() {
    printf "%b\n" "${yellow:-}$(date "+%Y-%m-%d %H:%M:%S")[WAR]:$1${normal:-}" >&3
}

say_err() {
    printf "%b\n" "${red:-}$(date "+%Y-%m-%d %H:%M:%S")[ERR]:$1${normal:-}" >&2
}

machine_has() {
    eval $invocation

    command -v "$1" >/dev/null 2>&1
    return $?
}

# args:
# remote_path - $1
get_http_header_curl() {
    eval $invocation

    local remote_path="$1"

    curl_options="-I -sSL --retry 5 --retry-delay 2 --connect-timeout 15 "
    curl $curl_options "$remote_path" 2>&1 || return 1
    return 0
}

# args:
# remote_path - $1
get_http_header_wget() {
    eval $invocation

    local remote_path="$1"
    local wget_options="-q -S --spider --tries 5 "
    # Store options that aren't supported on all wget implementations separately.
    local wget_options_extra="--waitretry 2 --connect-timeout 15 "
    local wget_result=''

    wget $wget_options $wget_options_extra "$remote_path" 2>&1
    wget_result=$?

    if [[ $wget_result == 2 ]]; then
        # Parsing of the command has failed. Exclude potentially unrecognized options and retry.
        wget $wget_options "$remote_path" 2>&1
        return $?
    fi

    return $wget_result
}

# Updates global variables $http_code and $download_error_msg
downloadcurl() {
    eval $invocation

    unset http_code
    unset download_error_msg
    local remote_path="$1"
    local out_path="${2:-}"
    local remote_path_with_credential="${remote_path}"
    local curl_options="--retry 20 --retry-delay 2 --connect-timeout 15 -sSL -f --create-dirs "
    local failed=false
    if [ -z "$out_path" ]; then
        curl $curl_options "$remote_path_with_credential" 2>&1 || failed=true
    else
        curl $curl_options -o "$out_path" "$remote_path_with_credential" 2>&1 || failed=true
    fi
    if [ "$failed" = true ]; then
        local response=$(get_http_header_curl $remote_path)
        http_code=$(echo "$response" | awk '/^HTTP/{print $2}' | tail -1)
        download_error_msg="Unable to download $remote_path."
        if [[ $http_code != 2* ]]; then
            download_error_msg+=" Returned HTTP status code: $http_code."
        fi
        say_verbose "$download_error_msg"
        return 1
    fi
    return 0
}

# Updates global variables $http_code and $download_error_msg
downloadwget() {
    eval $invocation

    unset http_code
    unset download_error_msg
    local remote_path="$1"
    local out_path="${2:-}"
    local remote_path_with_credential="${remote_path}"
    local wget_options="--tries 20 "
    # Store options that aren't supported on all wget implementations separately.
    local wget_options_extra="--waitretry 2 --connect-timeout 15 "
    local wget_result=''

    if [ -z "$out_path" ]; then
        wget -q $wget_options $wget_options_extra -O - "$remote_path_with_credential" 2>&1
        wget_result=$?
    else
        wget $wget_options $wget_options_extra -O "$out_path" "$remote_path_with_credential" 2>&1
        wget_result=$?
    fi

    if [[ $wget_result == 2 ]]; then
        # Parsing of the command has failed. Exclude potentially unrecognized options and retry.
        if [ -z "$out_path" ]; then
            wget -q $wget_options -O - "$remote_path_with_credential" 2>&1
            wget_result=$?
        else
            wget $wget_options -O "$out_path" "$remote_path_with_credential" 2>&1
            wget_result=$?
        fi
    fi

    if [[ $wget_result != 0 ]]; then
        local disable_feed_credential=false
        local response=$(get_http_header_wget $remote_path $disable_feed_credential)
        http_code=$(echo "$response" | awk '/^  HTTP/{print $2}' | tail -1)
        download_error_msg="Unable to download $remote_path."
        if [[ $http_code != 2* ]]; then
            download_error_msg+=" Returned HTTP status code: $http_code."
        fi
        say_verbose "$download_error_msg"
        return 1
    fi

    return 0
}

# args:
# remote_path - $1
# [out_path] - $2 - stdout if not provided
download() {
    eval $invocation

    local remote_path="$1"
    local out_path="${2:-}"

    if [[ "$remote_path" != "http"* ]]; then
        cp "$remote_path" "$out_path"
        return $?
    fi

    local failed=false
    local attempts=0
    while [ $attempts -lt 3 ]; do
        attempts=$((attempts + 1))
        failed=false
        if machine_has "curl"; then
            downloadcurl "$remote_path" "$out_path" || failed=true
        elif machine_has "wget"; then
            downloadwget "$remote_path" "$out_path" || failed=true
        else
            say_err "Missing dependency: neither curl nor wget was found."
            exit 1
        fi

        if [ "$failed" = false ] || [ $attempts -ge 3 ] || { [ ! -z $http_code ] && [ $http_code = "404" ]; }; then
            break
        fi

        say "Download attempt #$attempts has failed: $http_code $download_error_msg"
        say "Attempt #$((attempts + 1)) will start in $((attempts * 10)) seconds."
        sleep $((attempts * 10))
    done

    if [ "$failed" = true ]; then
        say_verbose "Download failed: $remote_path"
        return 1
    fi
    return 0
}
