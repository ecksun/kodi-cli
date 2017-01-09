#!/bin/bash

set -u
# set -x
set -o pipefail

print_help() {
cat <<EOF
Usage: $(basename "$0") <command>

commands:
    pause   Pause playback
    stop    Stop playback

EOF
}

create_json() {
    local method="$1"
    local params="$2"
    local RPC_DATA=$(jq --null-input \
        --arg id $RANDOM \
        --arg method "$method" \
        --arg params "$params" \
        "{
            jsonrpc: \"2.0\",
            method: \$method,
            params: ${params},
            id: \$id
        }")
    echo "$RPC_DATA"
}

is_error() {
    local rpc_response="$1"
    echo "$rpc_response" | jq --exit-status .error > /dev/null

    # If error is missing, we get exit status 1
    if [ "$?" -eq "1" ]; then
        return 1;
    fi;
    return 0;
}

call() {
    if [ ! -f "$HOME/.netrc.kodi" ]; then
        echo >&2 "$HOME/.netrc.kodi is missing"
        return 2
    fi
    local RPC_DATA=$(create_json "$@")
    local result=$(curl --silent --netrc-file ~/.netrc.kodi -H "Content-type: application/json" -X POST --data "$RPC_DATA" http://saga.ecksun.com/jsonrpc)

    echo "$result"
}

try_call() {
    local result call_status
    result=$(call "$@")

    call_status="$?"; [ "$call_status" -ne 0 ] && return "$call_status"

    if [ "$?" -ne 0 ] && is_error "$result"; then
        >&2 echo "Error while calling $1"
        >&2 echo "Got response:"
        echo "$result" | >&2 jq --color-output .
        return 1
    else
        echo "$result"
    fi
}

get_first_active_playerid() {
    local call_result call_status

    call_result=$(try_call Player.GetActivePlayers '[]')

    call_status="$?";
    if [ "$call_status" -ne 0 ]; then
        echo >&2 "Failed to get the current active player"
        return "$call_status"
    fi
    
    echo "$call_result" | jq .result[0].playerid
}

pause() {
    local first_player call_status
    first_player=$(get_first_active_playerid)
    call_status="$?"; [ "$call_status" -ne 0 ] && return "$call_status"

    if [[ "$first_player" == "null" ]]; then
        echo "Nothing is currently playing"
        return 2
    fi

    local speed=$(try_call Player.PlayPause "[${first_player}, \"toggle\"]" | jq .result.speed)

    [ "$speed" == "0" ] && echo "Paused"
    [ "$speed" == "1" ] && echo "Playing"
    return 0
}

stop() {
    local first_player call_status
    first_player=$(get_first_active_playerid)
    call_status="$?"; [ "$call_status" -ne 0 ] && return "$call_status"

    if [[ "$first_player" == "null" ]]; then
        echo "Nothing is currently playing"
        return 2
    fi

    try_call Player.Stop "[${first_player}]" > /dev/null
}

seek() {
    local first_player call_status
    first_player=$(get_first_active_playerid)
    call_status="$?"; [ "$call_status" -ne 0 ] && return "$call_status"

    if [[ "$first_player" == "null" ]]; then
        echo "Nothing is currently playing"
        return 2
    fi

    local time=$(try_call Player.Seek "[${first_player}, ${1}]" | jq .result.time)
    local minutes=$(echo "$time" | jq .minutes)
    local seconds=$(echo "$time" | jq .seconds)
    echo "Skipped to $(printf "%.2d" "$minutes"):$(printf "%.2d" "$seconds")"
}

seek_forward() {
    seek \"smallforward\"
}

seek_backward() {
    seek \"smallbackward\"
}

handle_args() {
    if [ "$#" -lt 1 ]; then
        >&2 echo "You need to specify a command"
        print_help
        exit 1
    fi

    for arg in "$@"; do
        case "$arg" in
            pause )
                pause
                break
            ;;
            stop )
                stop
                break
            ;;
            forward )
                seek_forward
                break
            ;;
            backward )
                seek_backward
                break
            ;;
            --help )
                print_help
                exit 0
            ;;
            * )
                >&2 echo "Unknown option/command $arg"
                print_help
                exit 1
            ;;
        esac
    done
}

handle_args "$@"
