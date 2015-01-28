#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/save.sh"

# check if my tty has a trigger file, if so, run history/buffer save

# setup the PROMPT_COMMAND
# PROMPT_COMMAND="source ~/dev/tmux-resurrect/scripts/prompt_runner.sh; tmxr_runner"

tmxr_runner() {
  if [[ -n "$TMUX" ]]; then
    local pane_id="$(get_pane_id)"
    local pane_tty="$(get_pane_tty "$pane_id")"
    local trigger_file_path="$(resurrect_trigger_file "$pane_id" "$pane_tty")"
    local tmxr_dump_flag=true # dump locally (without tmux send-keys)

    # nothing to do without a trigger!
    [[ ! -f "${trigger_file_path}" ]] && return 0

    # save pane history
    dump_bash_history "$pane_id" "$tmxr_dump_flag"

    # save pane buffer
    dump_pane_buffers "$pane_id" "$tmxr_dump_flag"

    # remove trigger file
    rm "${trigger_file_path}"
  fi

  return 0
}
