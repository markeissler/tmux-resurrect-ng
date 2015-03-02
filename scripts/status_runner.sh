#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/proc_helpers.sh"
source "$CURRENT_DIR/session_helpers.sh"

# setup the status-right in .tmux.conf
#
# append the following to the very end of the status-right configuration:
#   [#(~/dev/tmux-resurrect/scripts/save_auto.sh)]
#
# example:
# set -g status-right "...#[default][#(~/dev/tmux-resurrect/scripts/save_auto.sh)]"

main() {
  local session_name="$1"
  local session_time=$( (session_ctime "$session_name") || echo -1 )
  local srunner_path="$(session_srunner_file_path "$session_name" false "$session_time")"
  local status_interval=$(get_status_interval) # seconds
  local status_index=0
  local status_codes=( 'X' '-' 'S' 'R' 'D' '?' '!' )
  local purge_rslt

  # we must have a session name!
  [[ -z "$session_name" ]] && return 6 # fatal!

  # set global session variable
  set_session_name "$session_name"

  #
  # status index
  #   0 - disabled
  #   1 - enabled, pending progress
  #   2 - state saved/restored (not used for restore)
  #   3 - state, buffer, history saved/restored
  # 253 - enabled, delayed due to restore lock
  # 254 - error
  # 255 - fatal
  #

  if [[ -z "$session_time" || $session_time -lt 0 ]]; then
    #
    # fatal error - session time unavailable
    #
    status_index=6
  elif [[ ! -f "$srunner_path" ]]; then

    # save session metrics
    if [[ $(enable_debug_mode_on; echo $?) -eq 0 ]]; then
      local timeinsec=$(date +%s)
      local session_name="$(get_session_name)"
      local debug_file_path="/tmp/tmxr_${session_name}-metrics.txt"
      echo "    time_now: $timeinsec" > "$debug_file_path"
      echo "status_intvl: $status_interval" >> "$debug_file_path"
      echo "time_session: $session_time" >> "$debug_file_path"
    fi

    #
    # run restore_auto:
    #   - save_auto enabled and session_time less than frequency
    #   - save_auto disabled and session_time less than 15s
    #
    "$CURRENT_DIR/restore_auto.sh" "$session_name"
    status_index=$?
    [[ $status_index -eq 254 ]] && status_index=5
    [[ $status_index -eq 255 ]] && status_index=6

    # clear all actions
    session_purge_actions_all

    # clear all triggers
    session_purge_triggers_all

    # clear all srunners
    session_purge_srunners_all

    # create new srunner file
    touch "$srunner_path"
    [[ $? -ne 0 && $status_index -lt 6 ]] && status_index=5
  else
    #
    # run save_auto:
    #   - session_time greater than frequency
    #
    "$CURRENT_DIR/save_auto.sh" "$session_name"
    status_index=$?
    [[ $status_index -eq 253 ]] && status_index=4
    [[ $status_index -eq 254 ]] && status_index=5
    [[ $status_index -eq 255 ]] && status_index=6

    if [[ $status_index -eq 3 ]]; then
      if [[ $(enable_file_purge_on; echo $?) -eq 0 ]]; then
        # purge old state/history/buffer files
        purge_all_files "$session_name"; purge_rslt=$?
      fi

      # clear dead actions (actions for panes that no longer exist)
      session_purge_actions_dead

      # clear dead triggers (triggers for panes that no longer exist)
      session_purge_triggers_dead
    fi
  fi

  printf "%c\n" ${status_codes[$status_index]};

  return $status_index
}

main "$@"

# main provides a return value to pass on to caller
exit $?
