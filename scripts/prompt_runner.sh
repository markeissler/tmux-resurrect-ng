#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/session_helpers.sh"
source "$CURRENT_DIR/pane_helpers.sh"
source "$CURRENT_DIR/save_helpers.sh"

# check if my tty has a trigger file, if so, run history/buffer save

# setup the PROMPT_COMMAND
# PROMPT_COMMAND="source ~/dev/tmux-resurrect/scripts/prompt_runner.sh; tmxr_runner"

tmxr_runner() {
  local tmxr_runner_flag=true

  if [[ -n "$TMUX" && $(sanity_ok "$tmxr_runner_flag"; echo $?) -eq 0 ]]; then
    local session_name="$(get_session_name)"
    local pane_id="$(get_pane_id)"
    local pane_tty="$(get_pane_tty "$pane_id")"
    local trigger_file_path="$(pane_trigger_file_path "$pane_id" "$pane_tty")"
    local actions_file_path="$(pane_actions_file_path "$pane_id" "$pane_tty")"
    local tmxr_dump_flag=true # dump locally (without tmux send-keys)

    # no trigger? create the actions file
    if [[ ! -f "${trigger_file_path}" ]]; then
      touch "${actions_file_path}"
      return 0
    fi

    # save pane history
    dump_pane_histories "$session_name" "$pane_id" "$tmxr_dump_flag"

    # save pane buffer
    dump_pane_buffers "$session_name" "$pane_id" "$tmxr_dump_flag"

    # remove trigger file
    rm "${trigger_file_path}"

    # remove actions file
    rm "${actions_file_path}"
  fi

  return 0
}
