#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/restore_helpers.sh"
source "$CURRENT_DIR/spinner_helpers.sh"

restore_all() {
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
}

main() {
  if [[ $(sanity_ok; echo $?) -eq 0 ]]; then
    if check_saved_session_exists; then
      start_spinner "Restoring..." "Tmux restore complete!"
      restore_all
      stop_spinner
      display_message "Tmux restore complete!"
    else
      # session file missing!
      display_message "Tmux resurrect file not found!"
    fi
  fi
}
main
