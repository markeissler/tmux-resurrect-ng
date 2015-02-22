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

session_panes() {
  local session_name="$1"
  local list_target_opt=""

  # default behavior targets current session only
  [[ -n "$session_name" ]] && list_target_opt="-t \"$session_name\""

  tmux list-panes -s -F "$(session_pane_format)" $list_target_opt
}

# purge actions files for session
session_purge_actions() {
  local scope="$1"
  local session_name"${2}${2:-$(get_session_name)}" # defaults to client session
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
  IFS=$'\n'
  paneid_list=( $(session_panes $session_name) )
  IFS="$defaultIFS"

  # get list of panes, and stick in an assoc array
  while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command full_command; do
    local __paneid="$session_name:$window_number.$pane_index"
    paneid_list["$__paneid"]=1
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

# purge trigger file for session
session_purge_triggers() {
  local scope="$1"
  local session_name"${2}${2:-$(get_session_name)}" # defaults to pane session
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
  IFS=$'\n'
  paneid_list=( $(session_panes $session_name) )
  IFS="$defaultIFS"

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
