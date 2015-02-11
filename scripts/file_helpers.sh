# file_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#

_stat_mtime_command_strategy_file() {
  local stat_mtime_command_strategy="$(get_tmux_option "$stat_mtime_command_strategy_option" "$default_stat_mtime_command_strategy")"
  local strategy_file="$CURRENT_DIR/../command_strategies/${stat_mtime_command_strategy}.sh"
  local default_strategy_file="$CURRENT_DIR/../command_strategies/${default_stat_mtime_command_strategy}.sh"
  if [ -e "$strategy_file" ]; then # strategy file exists?
    echo "$strategy_file"
  else
    echo "$default_strategy_file"
  fi
}

stat_mtime() {
  local file_path="$1"
  local strategy_file="$(_stat_mtime_command_strategy_file)"
  # execute strategy script to get file timetamp
  $strategy_file "$file_path"

  return $?
}
