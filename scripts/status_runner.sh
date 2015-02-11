#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/proc_helpers.sh"

# check if we just started, if so, check if we need to restore a previous
# session, otherwise, run save-auto.

# setup the status-right in .tmux.conf
# append the following to the very end of the status-right configuration:
#   [#(~/dev/tmux-resurrect/scripts/save_auto.sh)]
# example:
# set -g status-right "...#[default][#(~/dev/tmux-resurrect/scripts/save_auto.sh)]"

main() {
  local session_name="$(get_session_name)"
  local session_time=$( (ps_session_etime "$session_name") || echo -1 )
  local frequency=$(save_auto_frequency) # minutes
  local frequency_sec=$(( frequency * 60 ))
  local status_index=0
  local status_codes=( 'X' '-' 'S' 'R' '?' '!' )

  echo "S: $session_time" > /tmp/sess.out
  echo "F: $frequency_sec" >> /tmp/sess.out

  if [[ $session_time -lt 0 ]]; then
    #
    # fatal error - session time unavailable
    #
    status_index=5
  elif [[ ( $frequency_sec -gt 0 && $session_time -lt $frequency_sec ) \
    || ( $frequency_sec -eq 0 && $session_time -lt 5 ) ]]; then
    #
    # run restore_auto:
    #   - save_auto enabled and session_time less than frequency
    #   - save_auto disabled and session_time less than 15s
    #
    "$CURRENT_DIR/restore_auto.sh"
    status_index=$?
    [[ $status_index -eq 255 ]] && status_index=4
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
