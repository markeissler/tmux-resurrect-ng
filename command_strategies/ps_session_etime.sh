#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SESSION_NAME="$1"

etime_to_seconds() {
  local time_string="$1"
  local time_string_array=()
  local time_seconds=0
  local return_status=0

  [[ -z "${time_string}" ]] && return 255

  # etime string returned by ps(1) consists one of three formats:
  #         31:24 (less than 1 hour)
  #      23:22:38 (less than 1 day)
  #   01-00:54:47 (more than 1 day)
  #

  # convert days component into just another element
  time_string="${time_string//-/:}"

  # split time_string into components separated by ':'
  time_string_array=( ${time_string//:/ } )

  # parse the array in reverse (smallest unit to largest)
  local _elem=""
  local _indx=1
  for(( i=${#time_string_array[@]}; i>0; i-- )); do
    # strip leading zeroes to avoid bash int error
    _elem="${time_string_array[$i-1]##0}"
    case ${_indx} in
      1 )
        (( time_seconds+=${_elem} ))
        ;;
      2 )
        (( time_seconds+=${_elem}*60 ))
        ;;
      3 )
        (( time_seconds+=${_elem}*3600 ))
        ;;
      4 )
        (( time_seconds+=${_elem}*86400 ))
        ;;
    esac
    (( _indx++ ))
  done
  unset _indx
  unset _elem

  echo -n "$time_seconds"; return $return_status
}

exit_safely_if_empty_session() {
  if [ -z "$SESSION_NAME" ]; then
    exit 1
  fi
}

ps_command_flags() {
  case $(uname -s) in
    FreeBSD) ;&
    OpenBSD)
      echo "-ao"
      ;;
    *)
      echo "-eo"
      ;;
  esac
}

full_command() {
  local proc_string=""
  local time_string=""
  local time_string_secs=""
  local return_status=0

  proc_string="$(ps "$(ps_command_flags)" "ppid,etime,command" \
    | grep -E "[t]mux\s([[:alnum:][:punct:]]+)\s\-s\s$SESSION_NAME\s.*$")"

  if [[ $? -ne 0 ]]; then
    return_status=1
  else
    time_string="$(echo "$proc_string" | awk '{ print $2 }')"
  fi

  time_string_secs="$(etime_to_seconds "$time_string")"

  echo -n "$time_string_secs"; return $return_status
}

main() {
  exit_safely_if_empty_session
  full_command
  return $?
}
main
exit $?
