# pane_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#

_pane_full_command_strategy_file() {
  local strategy="$(get_tmux_option "$pane_full_command_strategy_option" "$default_pane_full_command_strategy")"
  local strategy_dep="$(get_tmux_option "$dep_pane_full_command_strategy_option" "")"
  local strategy_file="$CURRENT_DIR/../command_strategies/${strategy}.sh"
  local strategy_file_def="$CURRENT_DIR/../command_strategies/${default_pane_full_command_strategy}.sh"

  # support deprecated option name
  [[ -n "$strategy_dep" ]] && strategy_file="$CURRENT_DIR/../command_strategies/${strategy_dep}.sh"

  # always fall back to default strategy
  if [ -e "$strategy_file" ]; then
    echo "$strategy_file"
  else
    echo "$strategy_file_def"
  fi
}

pane_full_command() {
  local pane_pid="$1"
  local strategy_file="$(_pane_full_command_strategy_file)"
  # execute strategy script to get pane full command
  $strategy_file "$pane_pid"

  return $?
}
