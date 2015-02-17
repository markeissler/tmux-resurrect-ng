#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/pane_helpers.sh"
source "$CURRENT_DIR/save_helpers.sh"
source "$CURRENT_DIR/spinner_helpers.sh"

save_all() {
  local resurrect_file_path="$(resurrect_file_path)"
  mkdir -p "$(resurrect_dir)"
  dump_version >  "$resurrect_file_path"
  dump_panes   >> "$resurrect_file_path"
  dump_windows >> "$resurrect_file_path"
  dump_state   >> "$resurrect_file_path"
  ln -fs "$(basename "$resurrect_file_path")" "$(last_resurrect_file)"
  if enable_pane_history_on; then
    dump_pane_histories
  fi
  if enable_pane_buffers_on; then
    dump_pane_buffers
  fi
  restore_zoomed_windows
}

main() {
  if [[ $(sanity_ok; echo $?) -eq 0 ]]; then
    start_spinner "Saving..." "Tmux environment saved!"
    save_all
    stop_spinner
    display_message "Tmux environment saved!"
  fi
}

main
