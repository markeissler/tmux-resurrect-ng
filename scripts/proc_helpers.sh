# proc_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#

_session_etime_command_strategy_file() {
  local strategy="$(get_tmux_option "$session_etime_command_strategy_option" "$default_session_etime_command_strategy")"
  local strategy_file="$CURRENT_DIR/../command_strategies/${strategy}.sh"
  local strategy_file_def="$CURRENT_DIR/../command_strategies/${default_session_etime_command_strategy}.sh"

  # always fall back to default strategy
  if [ -e "$strategy_file" ]; then
    echo "$strategy_file"
  else
    echo "$strategy_file_def"
  fi
}

session_etime() {
  local file_path="$1"
  local strategy_file="$(_session_etime_command_strategy_file)"
  # execute strategy script to get session age
  $strategy_file "$file_path"

  return $?
}
