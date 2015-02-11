# proc_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#

_ps_session_etime_command_strategy_file() {
  local ps_session_etime_command_strategy="$(get_tmux_option "$ps_session_etime_command_strategy_option" "$default_ps_session_etime_command_strategy")"
  local strategy_file="$CURRENT_DIR/../command_strategies/${ps_session_etime_command_strategy}.sh"
  local default_strategy_file="$CURRENT_DIR/../command_strategies/${default_ps_session_etime_command_strategy}.sh"
  if [ -e "$strategy_file" ]; then # strategy file exists?
    echo "$strategy_file"
  else
    echo "$default_strategy_file"
  fi
}

ps_session_etime() {
  local file_path="$1"
  local strategy_file="$(_ps_session_etime_command_strategy_file)"
  # execute strategy script to get session age
  $strategy_file "$file_path"

  return $?
}
