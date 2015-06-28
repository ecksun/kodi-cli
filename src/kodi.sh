#!/bin/bash

set -u
# set -x

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
    local RPC_DATA=$(create_json "$@")
    local result=$(curl --silent --netrc-file ~/.netrc.kodi -H "Content-type: application/json" -X POST --data "$RPC_DATA" http://saga.ecksun.com/jsonrpc)

    echo "$result"
}

try_call() {
    local result=$(call "$@")

    if is_error "$result"; then
        >&2 echo "Error while calling $1"
        >&2 echo "Got response:"
        echo "$result" | >&2 jq --color-output .
        return 1
    else
        echo "$result"
    fi
}

get_first_active_playerid() {
    try_call Player.GetActivePlayers '[]' | jq .result[0].playerid
}

pause() {
    local first_player=$(get_first_active_playerid)
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
    local first_player=$(get_first_active_playerid)
    if [[ "$first_player" == "null" ]]; then
        echo "Nothing is currently playing"
        return 2
    fi

    try_call Player.Stop "[${first_player}]" > /dev/null
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
