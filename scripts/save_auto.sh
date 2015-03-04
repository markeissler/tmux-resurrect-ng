#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/file_helpers.sh"
source "$CURRENT_DIR/session_helpers.sh"
source "$CURRENT_DIR/pane_helpers.sh"
source "$CURRENT_DIR/save_helpers.sh"

save_all_states() {
  local session_name="$1"
  local resurrect_file_path="$(resurrect_file_path "$session_name")"

  mkdir -p "$(resurrect_dir)"
  dump_version >  "$resurrect_file_path"
  dump_panes "$session_name"  >> "$resurrect_file_path"
  dump_windows "$session_name" >> "$resurrect_file_path"
  ln -fs "$(basename "$resurrect_file_path")" "$(last_resurrect_file "$session_name")"
  restore_zoomed_windows "$session_name"
}

update_pane_trigger() {
  local pane_id="$1"
  local pane_command="$2"
  local pane_full_command="$3"
  local pane_tty="$(get_pane_tty "$pane_id")"
  local buffer_file_pattern="$(pane_buffer_file_path "${pane_id}" "true")"
  local buffer_file_path_list=()
  local buffer_file_path=""
  local buffer_file_extension=".txt"
  local history_file_pattern="$(pane_history_file_path "${pane_id}" "true")"
  local history_file_extension=".txt"
  local history_file_path=""
  local actions_file_path="$(pane_actions_file_path "$pane_id" "$pane_tty")"
  local trigger_file_path="$(pane_trigger_file_path "$pane_id" "$pane_tty")"
  local timeinsec=$(date +%s)
  local frequency=$(save_auto_frequency) # minutes
  local frequency_sec=$(( frequency * 60 ))
  local return_status=0
  local stderr_status=0

  # must have a pane_id!
  [[ -z "$pane_tty" ]] && return 255

  # only trigger if current command is a shell
  [[ "$pane_command" != "bash" || "$pane_full_command" != ":" ]] && return $return_status

  # figure out buffer file extension
  if [[ $(enable_pane_ansi_buffers_on; echo $?) -eq 0 ]]; then
    buffer_file_extension=".ans"
  fi
  buffer_file_pattern+="$buffer_file_extension"

  # figure out history file extension
  if [[ "$(get_pane_command)" == "bash" ]]; then
    history_file_extension=".bsh"
  fi
  history_file_pattern+="$history_file_extension"

  # find the most-recent buffer file
  IFS=$'\n'
  stderr_status=$(ls -1 $buffer_file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  buffer_file_path_list=( $(ls -1 $buffer_file_pattern 2>/dev/null) )
  buffer_file_path=$(echo "${buffer_file_path_list[*]}" | sort -r | head -1)
  IFS="$defaultIFS"

  # find the most-recent history file
  IFS=$'\n'
  stderr_status=$(ls -1 $history_file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  history_file_path_list=( $(ls -1 $history_file_pattern 2>/dev/null) )
  history_file_path=$(echo "${history_file_path_list[*]}" | sort -r | head -1)
  IFS="$defaultIFS"

  # if there is no corresponding actions file (which indicates activity has
  # occurred to update history/buffer), we just bail out now.
  [[ ! -f "$actions_file_path" ]] && return $return_status

  # if history/buffer files are missing or one of them is old, update trigger
  local buffer_file_mtime=$( (stat_mtime $buffer_file_path) || echo -1 )
  local buffer_file_staterr=0
  local history_file_mtime=$( (stat_mtime $history_file_path) || echo -1 )
  local history_file_staterr=0
  [[ $buffer_file_mtime -lt 0 ]] && buffer_file_staterr=1
  [[ $history_file_mtime -lt 0 ]] && history_file_staterr=1

  # Status reflected in tmux status bar is always behind by one check.
  #
  if [[ $buffer_file_staterr -ne 0 || $history_file_staterr -ne 0 ]]; then
    # no history OR buffer file exists
    return_status=2
  elif [[ $(( timeinsec - buffer_file_mtime )) -gt $frequency_sec \
    || $(( timeinsec - history_file_mtime )) -gt $frequency_sec ]]; then
    # stale history OR buffer file exists
    return_status=1
  fi

  # save updated history/buffers files if no files exist or files are stale
  if [[ $(enable_debug_mode_on; echo $?) -eq 0 ]]; then
    local debug_file_path="/tmp/tmxr_${pane_id}:${pane_tty//\//@}.txt"
    echo "     time_now: $timeinsec" > "$debug_file_path"
    echo " buffer_mtime: $buffer_file_mtime" >> "$debug_file_path"
    echo "   buffer_age: $(( timeinsec - buffer_file_mtime ))" >> "$debug_file_path"
    echo "  buffer_path: $buffer_file_path" >> "$debug_file_path"
    echo "history_mtime: $history_file_mtime" >> "$debug_file_path"
    echo "  history_age: $(( timeinsec - history_file_mtime ))" >> "$debug_file_path"
    echo " history_path: $history_file_path" >> "$debug_file_path"
    echo " trigger_path: $trigger_file_path" >> "$debug_file_path"
    echo "  update_code: $return_status" >> "$debug_file_path"
  fi
  [[ $return_status -gt 0 ]] && touch "${trigger_file_path}"

  return $return_status
}

update_pane_triggers() {
  local session_name="$1"
  local return_status=0

  while IFS=$'\t' read _line_type _session_name _window_number _window_name _window_active _window_flags _pane_index _dir _pane_active _pane_command _full_command; do
    local __pane_id="${_session_name}:${_window_number}.${_pane_index}"
    update_pane_trigger "${__pane_id}" "${_pane_command}" "${_full_command}"
    local rslt=$?
    [[ $rslt -gt $return_status ]] && return_status=$rslt
  done <<< "$(session_panes "$session_name")"

  return $return_status
}

update_state() {
  local session_name="$1"
  local state_file_pattern="$(resurrect_file_path "$session_name" "true")"
  local state_file_path_list=()
  local state_file_path=""
  local timeinsec=$(date +%s)
  local frequency=$(save_auto_frequency) # minutes
  local frequency_sec=$(( frequency * 60 ))
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # find the most-recent layout/state file
  IFS=$'\n'
  stderr_status=$(ls -1 $state_file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  state_file_path_list=( $(ls -1 $state_file_pattern 2>/dev/null) )
  state_file_path=$(echo "${state_file_path_list[*]}" | sort -r | head -1)
  IFS="$defaultIFS"

  # calculate age of layout/state file, save state if old or missing
  local state_file_mtime=$( (stat_mtime $state_file_path) || echo -1 )
  local state_file_staterr=0
  [[ $state_file_mtime -lt 0 ]] && state_file_staterr=1

  # Status reflected in tmux status bar is always behind by one check.
  #
  if [[ $state_file_staterr -ne 0 ]]; then
    # no state file exists
    return_status=2
  elif [[ $(( timeinsec - state_file_mtime )) -gt $frequency_sec ]]; then
    # stale state file exists
    return_status=1
  fi

  # save updated state if no file exists or file is stale
  if [[ $(enable_debug_mode_on; echo $?) -eq 0 ]]; then
    local debug_file_path="/tmp/tmxr_${session_name}.txt"
    echo " state file: $state_file_path" > "$debug_file_path"
    echo "   time_now: $timeinsec" >> "$debug_file_path"
    echo "state_mtime: $state_file_mtime" >> "$debug_file_path"
    echo "  state_age: $(( timeinsec - state_file_mtime ))" >> "$debug_file_path"
    echo "update_code: $return_status" >> "$debug_file_path"
  fi
  [[ $return_status -gt 0 ]] && save_all_states "$session_name"

  return $return_status
}

main() {
  if [[ $(sanity_ok; echo $?) -eq 0 ]]; then
    local session_name="$1"
    local state_rslt trigger_rslt purge_rslt
    local status_index=0

    # we must have a session name!
    [[ -z "$session_name" ]] && return 255

    # set global session variable
    set_session_name "$session_name"

    #
    # status index
    #   0 - disabled
    #   1 - enabled, pending progress
    #   2 - state saved (state-recoverable)
    #   3 - state, buffer, history saved (recoverable)
    # 253 - enabled, delayed due to restore lock
    # 254 - error
    # 255 - fatal
    #

    if [[ $(enable_save_auto_on; echo $?) -eq 0 ]]; then
      # save_auto is enabled, bump up status_index
      (( status_index++ ))

      # delay if restore is in progress
      [[ -f "$(restore_lock_file_path "$session_name")" ]] && return 253

      # save all states
      update_state "$session_name"; state_rslt=$?

      # save history/buffer triggers
      update_pane_triggers "$session_name"; trigger_rslt=$?

      # return auto save status code
      [[ $state_rslt -eq 0 ]] && (( status_index++ ))
      [[ $status_index -eq 2 && $trigger_rslt -eq 0 ]] && (( status_index++ ))
    fi

    if [[ $(enable_file_purge_on; echo $?) -eq 0 && $status_index -eq 3 ]]; then
      # purge old state/history/buffer files
      purge_all_files "$session_name"; purge_rslt=$?
    fi
  else
    # tmux version unsupported!
    status_index=255
  fi

  return $status_index
}

main "$@"

# main provides a return value to pass on to caller
exit $?
