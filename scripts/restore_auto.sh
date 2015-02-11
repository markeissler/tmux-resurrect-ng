#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/restore_helpers.sh"
source "$CURRENT_DIR/spinner_helpers.sh"

restore_all() {
  local return_status=0

  restore_all_panes
  restore_pane_layout_for_each_window >/dev/null 2>&1
  if enable_pane_history_on; then
    restore_pane_histories
  fi
  if enable_pane_buffers_on; then
    # ttys need to settle after getting cleared
    sleep 2
    restore_pane_buffers
  fi
  restore_all_pane_processes
  # below functions restore exact cursor positions
  restore_active_pane_for_each_window
  restore_zoomed_windows
  restore_active_and_alternate_windows
  restore_active_and_alternate_sessions

  return $return_status
}

main() {
  if supported_tmux_version_ok; then
    local restore_rslt
    local status_index=0

    #
    # status index
    #   0 - disabled
    #   1 - enabled, pending progress
    #   2 - state restored (not used)
    #   3 - state, buffer, history restored (recovered)
    # 254 - error
    # 255 - fatal
    #

    if [[ $(enable_restore_auto_on; echo $?) -eq 0 ]]; then
      # restore_auto is enabled, bump up status_index
      (( status_index++ ))

      if [[ $(check_saved_session_exists; echo $?) -eq 0 ]]; then
        #
        # @TODO: need to check for saved history/buffers too!
        #

        # we have state files
        start_spinner "Restoring..." "Auto restore complete!"
        restore_all; restore_rslt=$?
        stop_spinner
        display_message "Tmux restore complete!"

        # return auto restore status code
        [[ $restore_rslt -eq 0 ]] && (( status_index+=2 ))
      fi
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
