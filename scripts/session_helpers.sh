# session_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#

SESSION_PURGE_TRIGGERS_ALL=1
SESSION_PURGE_TRIGGERS_DEAD=2
SESSION_PURGE_ACTIONS_ALL=1
SESSION_PURGE_ACTIONS_DEAD=2
SESSION_PURGE_SRUNNERS_ALL=1
SESSION_PURGE_SRUNNERS_DEAD=2

session_ctime() {
  local session_name"${1:-$(get_session_name)}" # defaults to pane session

  # display created time (as an integer) for session_name
  tmux display-message -t "$session_name" -p "#{session_created}"
}

session_etime() {
  local session_name"${1:-$(get_session_name)}" # defaults to pane session
  local session_ctime=$(session_ctime "$session_name")
  local session_etime=0
  local timeinsec=$(date +%s)

  session_etime=$(( $timeinsec-$session_ctime ))

  [[ -z $session_etime || $session_etime -lt 0 ]] && session_etime=-1

  echo "$session_etime"; return 1
}

session_exists() {
  local session_name="$1"

  tmux has-session -t "$session_name" 2>/dev/null
}

session_first_window_num() {
  tmux show -gv base-index
}

session_new() {
  local session_name="$1"
  local window_number="$2"
  local window_name="$3"
  local dir="$4"

  TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -n "$window_name" -c "$dir"
  # change first window number if necessary
  local created_window_num="$(session_first_window_num)"
  if [ $created_window_num -ne $window_number ]; then
    tmux move-window -s "${session_name}:${created_window_num}" -t "${session_name}:${window_number}"
  fi
}

session_pane_format() {
  local delimiter=$'\t'
  local format
  format+="pane"
  format+="${delimiter}"
  format+="#{session_name}"
  format+="${delimiter}"
  format+="#{window_index}"
  format+="${delimiter}"
  format+=":#{window_name}"
  format+="${delimiter}"
  format+="#{window_active}"
  format+="${delimiter}"
  format+=":#{window_flags}"
  format+="${delimiter}"
  format+="#{pane_index}"
  format+="${delimiter}"
  format+=":#{pane_current_path}"
  format+="${delimiter}"
  format+="#{pane_active}"
  format+="${delimiter}"
  format+="#{pane_current_command}"
  format+="${delimiter}"
  format+="#{pane_pid}"
  echo "$format"
}

session_panes_raw() {
  local session_name="$1"
  local list_target_opt=""

  # default behavior targets current session only
  [[ -n "$session_name" ]] && list_target_opt="-t \"$session_name\""

  tmux list-panes -s -F "$(session_pane_format)" $list_target_opt
}

# translates pane pid to process command running inside a pane
session_panes() {
  local session_name="$1" # optional
  local full_command pane_data
  local d=$'\t' # delimiter

  session_panes_raw "$session_name" |
    while IFS=$'\t' read _line_type _session_name _window_number _window_name _window_active _window_flags _pane_index _dir _pane_active _pane_command _pane_pid; do
      # check if current pane is part of a maximized window and if the pane is active
      if [[ "${_window_flags}" == *Z* ]] && [[ ${_pane_active} == 1 ]]; then
        # unmaximize the pane
        tmux resize-pane -Z -t "${_session_name}:${_window_number}"
      fi
      full_command="$(pane_full_command ${_pane_pid})"

      pane_data="${_line_type}"
      pane_data+="${d}${_session_name}"
      pane_data+="${d}${_window_number}"
      pane_data+="${d}${_window_name}"
      pane_data+="${d}${_window_active}"
      pane_data+="${d}${_window_flags}"
      pane_data+="${d}${_pane_index}"
      pane_data+="${d}${_dir}"
      pane_data+="${d}${_pane_active}"
      pane_data+="${d}${_pane_command}"
      pane_data+="${d}:${full_command}"

      echo "$pane_data"
    done
}

# purge actions files for session
session_purge_actions() {
  local scope="$1"
  local session_name="${2:-$(get_session_name)}" # defaults to client session
  local action_file_pattern="$(pane_actions_file_path "$session_name*" "*")"
  local action_file_path_list=()
  local action_file_path_list_sorted=()
  local paneid_pattern='s/^.*-([[:alnum:][:punct:]]+:[[:digit:]]+\.[[:digit:]]+):((@[[:alnum:]]+)+)$/\1/'
  local -A paneid_list=()
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # set scope
  case "$scope" in
    "$SESSION_PURGE_ACTIONS_ALL" ) ;&
    "$SESSION_PURGE_ACTIONS_DEAD" )
      ;;
    *)
      scope="$SESSION_PURGE_ACTIONS_ALL"
      ;;
  esac

  # get list of actions
  IFS=$'\n'
  stderr_status=$(ls -1 $action_file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  action_file_path_list=( $(ls -1 $action_file_pattern 2>/dev/null) )
  action_file_path_list_sorted=( $(echo "${action_file_path_list[*]}" | sort -r) )
  IFS="$defaultIFS"

  # get list of panes
  # IFS=$'\n'
  # paneid_list=( $(session_panes $session_name) )
  # IFS="$defaultIFS"

  # get list of panes, and stick in an assoc array
  while IFS=$'\t' read _line_type _session_name _window_number _window_name _window_active _window_flags _pane_index _dir _pane_active _pane_command _full_command; do
    local __paneid="${_session_name}:${_window_number}.${_pane_index}"
    paneid_list["${__paneid}"]=1
  done < <(session_panes $session_name)

  # iterate over path list, deleting actions associated with a dead pane
  local _file _file_basename _file_paneid
  for _file in "${action_file_path_list_sorted[@]}"; do
    if [[ "$scope" -eq $SESSION_PURGE_ACTIONS_DEAD ]]; then
      _file_basename="$(basename "${_file}")"
      _file_paneid="$(echo "${_file_basename}" \
        | sed -E -e "$paneid_pattern" -e 'tx' -e 'd' -e ':x')"

      # we need a _file_paneid!
      [[ -z "${_file_paneid}" ]] && return_status=1 && break

      # _file_paneid in paneid_list assoc array? leave it alone!
      [[ -n "${paneid_list[$_file_paneid]}" ]] && continue

    elif [[ "$scope" -ne $SESSION_PURGE_ACTIONS_ALL ]]; then
      # anything else is an error
      return_status=255 && break
    fi
    rm -f "${_file}" > /dev/null 2>&1
    [[ $? -ne 0 ]] && return_status=1 && break
  done
  unset _file _file_basename _file_paneid

  return $return_status
}

# purge all actions files for session
session_purge_actions_all() {
  local session_name"$1" # optional

  session_purge_actions "$SESSION_PURGE_ACTIONS_ALL" "$session_name"

  return $?
}

# purge actions files for panes that no longer exist in session
session_purge_actions_dead() {
  local session_name"$1" # optional

  session_purge_actions "$SESSION_PURGE_ACTIONS_DEAD" "$session_name"

  return $?
}

# purge trigger files for session
session_purge_triggers() {
  local scope="$1"
  local session_name="${2:-$(get_session_name)}" # defaults to pane session
  local trigger_file_pattern="$(pane_trigger_file_path "$session_name*" "*")"
  local trigger_file_path_list=()
  local trigger_file_path_list_sorted=()
  local paneid_pattern='s/^.*-([[:alnum:][:punct:]]+:[[:digit:]]+\.[[:digit:]]+):((@[[:alnum:]]+)+)$/\1/'
  local -A paneid_list=()
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # set scope
  case "$scope" in
    "$SESSION_PURGE_TRIGGERS_ALL" ) ;&
    "$SESSION_PURGE_TRIGGERS_DEAD" )
      ;;
    *)
      scope="$SESSION_PURGE_TRIGGERS_ALL"
      ;;
  esac

  # get list of triggers
  IFS=$'\n'
  stderr_status=$(ls -1 $trigger_file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  trigger_file_path_list=( $(ls -1 $trigger_file_pattern 2>/dev/null) )
  trigger_file_path_list_sorted=( $(echo "${trigger_file_path_list[*]}" | sort -r) )
  IFS="$defaultIFS"

  # get list of panes
  # IFS=$'\n'
  # paneid_list=( $(session_panes $session_name) )
  # IFS="$defaultIFS"

  # get list of panes, and stick in an assoc array
  while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command full_command; do
    local __paneid="$session_name:$window_number.$pane_index"
    paneid_list["$__paneid"]=1
  done < <(session_panes $session_name)

  # iterate over path list, deleting triggers associated with a dead pane
  local _file _file_basename _file_paneid #_file_sessionid
  for _file in "${trigger_file_path_list_sorted[@]}"; do
    if [[ "$scope" -eq $SESSION_PURGE_TRIGGERS_DEAD ]]; then
      _file_basename="$(basename "${_file}")"
      _file_paneid="$(echo "${_file_basename}" \
        | sed -E -e "$paneid_pattern" -e 'tx' -e 'd' -e ':x')"

      # we need a _file_paneid!
      [[ -z "${_file_paneid}" ]] && return_status=1 && break

      # _file_paneid in paneid_list assoc array? leave it alone!
      [[ -n "${paneid_list[$_file_paneid]}" ]] && continue

    elif [[ "$scope" -ne $SESSION_PURGE_TRIGGERS_ALL ]]; then
      # anything else is an error
      return_status=255 && break
    fi
    rm -f "${_file}" > /dev/null 2>&1
    [[ $? -ne 0 ]] && return_status=1 && break
  done
  unset _file _file_basename _file_paneid #_file_sessionid

  return $return_status
}

# purge all trigger files for session
session_purge_triggers_all() {
  local session_name"$1" # optional

  session_purge_triggers "$SESSION_PURGE_TRIGGERS_ALL" "$session_name"

  return $?
}

# purge trigger files for panes that no longer exist in session
session_purge_triggers_dead() {
  local session_name"$1" # optional

  session_purge_triggers "$SESSION_PURGE_TRIGGERS_DEAD" "$session_name"

  return $?
}

# purge srunner files for session
session_purge_srunners() {
  local scope="$1"
  local session_name="${2:-$(get_session_name)}" # defaults to pane session
  local session_time="$(session_ctime "$session_name")"
  local srunner_file_pattern="$(session_srunner_file_path "$session_name" true)"
  local srunner_file_path_list=()
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # set scope
  case "$scope" in
    "$SESSION_PURGE_SRUNNERS_ALL" ) ;&
    "$SESSION_PURGE_SRUNNERS_DEAD" )
      ;;
    *)
      scope="$SESSION_PURGE_SRUNNERS_ALL"
      ;;
  esac

  # get list of srunners
  IFS=$'\n'
  stderr_status=$(ls -1 $srunner_file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  srunner_file_path_list=( $(ls -1 $srunner_file_pattern 2>/dev/null) )
  IFS="$defaultIFS"

  # iterate over path list, deleting srunners associated with a dead session
  # or all srunners found; dead sessions are those where the session ctime is
  # older than the current session of the same name.
  local _file _file_session_ctime
  for _file in "${srunner_file_path_list[@]}"; do
    if [[ "$scope" -eq $SESSION_PURGE_SRUNNERS_DEAD ]]; then
      _file_session_ctime="$(find_timestamp_from_file "${_file}")"

      # we need a _file_session_ctime!
      [[ -z "${_file_session_ctime}" ]] && return_status=1 && break

      # _file_session_ctime is current session? leave it alone!
      [[ "${_file_session_ctime}" == "${session_time}" ]] && continue

    elif [[ "$scope" -ne $SESSION_PURGE_SRUNNERS_ALL ]]; then
      # anything else is an error
      return_status=255 && break
    fi
    rm -f "${_file}" > /dev/null 2>&1
    [[ $? -ne 0 ]] && return_status=1 && break
  done
  unset _file _file_session_ctime

  return $return_status
}

session_purge_srunners_all() {
  local session_name"$1" # optional

  session_purge_srunners "$SESSION_PURGE_SRUNNERS_ALL" "$session_name"

  return $?
}

session_purge_srunners_dead() {
  local session_name"$1" # optional

  session_purge_srunners "$SESSION_PURGE_SRUNNERS_DEAD" "$session_name"

  return $?
}

session_srunner_file_path() {
  # support for empty parameters (passed as empty string values)
  local session_name="${1:-$(get_session_name)}"; shift
  local use_globstamp="${1:-false}"; shift
  local timestamp="${1:-$(session_ctime "$session_name")}";
  local globstamp='[0-9]*'

  # must have a session_name!
  [[ -z "$session_name" ]] && echo "" && return 1

  # check sanity of vars
  [[ "$use_globstamp" != true && "$use_globstamp" != false ]] && use_globstamp="false"

  # globstamp instead of timestamp?
  [[ "$use_globstamp" == true ]] && timestamp="$globstamp"

  echo "$(resurrect_dir)/.srunner-${session_name}_${timestamp}.run"
}

session_state_exists() {
  local session_name="$1"
  local resurrect_file_path="$(last_resurrect_file "$session_name")"

  # failed to construct file path!
  [[ $? -ne 0 ]] && return 255

  if [ ! -f $resurrect_file_path ]; then
    return 1
  fi
}

session_window_exists() {
  local session_name="$1"
  local window_number="$2"

  tmux list-windows -t "$session_name" -F "#{window_index}" 2>/dev/null |
    \grep -q "^$window_number$"
}
