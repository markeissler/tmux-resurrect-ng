# pane_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#

_full_command_strategy_file() {
  local save_command_strategy="$(get_tmux_option "$save_command_strategy_option" "$default_save_command_strategy")"
  local strategy_file="$CURRENT_DIR/../save_command_strategies/${save_command_strategy}.sh"
  local default_strategy_file="$CURRENT_DIR/../save_command_strategies/${default_save_command_strategy}.sh"
  if [ -e "$strategy_file" ]; then # strategy file exists?
    echo "$strategy_file"
  else
    echo "$default_strategy_file"
  fi
}

full_command() {
  local pane_pid="$1"
  local strategy_file="$(_full_command_strategy_file)"
  # execute strategy script to get pane full command
  $strategy_file "$pane_pid"

  return $?
}
