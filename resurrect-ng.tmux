#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/variables.sh"
source "$CURRENT_DIR/scripts/helpers.sh"

set_save_bindings() {
  local key_bindings=$(get_tmux_option "$save_option" "$default_save_key")
  local key
  for key in $key_bindings; do
    tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/save.sh"
  done
}

set_restore_bindings() {
  local key_bindings=$(get_tmux_option "$restore_option" "$default_restore_key")
  local key
  for key in $key_bindings; do
    tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/restore.sh"
  done
}

set_default_strategies() {
  tmux set-option -g "${restore_process_strategy_option}irb" "default_strategy"
}

main() {
  set_save_bindings
  set_restore_bindings
  set_default_strategies
}
main
