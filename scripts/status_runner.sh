#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/proc_helpers.sh"

# setup the status-right in .tmux.conf
#
# append the following to the very end of the status-right configuration:
#   [#(~/dev/tmux-resurrect/scripts/save_auto.sh)]
#
# example:
# set -g status-right "...#[default][#(~/dev/tmux-resurrect/scripts/save_auto.sh)]"

main() {
  local session_name="$(get_session_name)"
  local session_time=$( (ps_session_etime "$session_name") || echo -1 )
  local status_interval=$(get_status_interval) # seconds
  local status_index=0
  local status_codes=( 'X' '-' 'S' 'R' '?' '!' )

  #
  # status index
  #   0 - disabled
  #   1 - enabled, pending progress
  #   2 - state saved/restored (not used for restore)
  #   3 - state, buffer, history saved/restored
  # 254 - error
  # 255 - fatal
  #

  if [[ -z "$session_time" || $session_time -lt 0 ]]; then
    #
    # fatal error - session time unavailable
    #
    status_index=5
  elif [[ ( $status_interval -gt 0 && $session_time -lt $status_interval ) \
    || ( $status_interval -eq 0 && $session_time -lt 5 ) ]]; then

    #
    # run restore_auto:
    #   - save_auto enabled and session_time less than frequency
    #   - save_auto disabled and session_time less than 15s
    #
    "$CURRENT_DIR/restore_auto.sh"
    status_index=$?
    [[ $status_index -eq 255 ]] && status_index=4

    # clear all actions
    purge_actions_files

    # clear all triggers
    purge_trigger_files
  else
    #
    # run save_auto:
    #   - session_time greater than frequency
    #
    "$CURRENT_DIR/save_auto.sh"
    status_index=$?
  fi

  printf "%c\n" ${status_codes[$status_index]};
}

main
