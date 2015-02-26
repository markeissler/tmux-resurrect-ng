#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/pane_helpers.sh"
source "$CURRENT_DIR/save_helpers.sh"
source "$CURRENT_DIR/spinner_helpers.sh"

save_all() {
  local session_name="$1"
  local resurrect_file_path="$(resurrect_file_path "$session_name")"

  mkdir -p "$(resurrect_dir)"
  dump_version > "$resurrect_file_path"
  dump_panes "$session_name" >> "$resurrect_file_path"
  dump_windows "$session_name" >> "$resurrect_file_path"
  dump_state >> "$resurrect_file_path"
  ln -fs "$(basename "$resurrect_file_path")" "$(last_resurrect_file "$session_name")"
  if enable_pane_history_on; then
    dump_pane_histories "$session_name"
  fi
  if enable_pane_buffers_on; then
    dump_pane_buffers "$session_name"
  fi
  restore_zoomed_windows "$session_name"
}

main() {
  if [[ $(sanity_ok; echo $?) -eq 0 ]]; then
    local session_name="$(get_session_name)"

    start_spinner "Saving..."
    save_all "$session_name"
    stop_spinner
    display_message "Environment saved!"
  fi
}

main
