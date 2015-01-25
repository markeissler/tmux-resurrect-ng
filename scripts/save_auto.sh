#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# source "$CURRENT_DIR/variables.sh"
# source "$CURRENT_DIR/helpers.sh"
# source "$CURRENT_DIR/spinner_helpers.sh"
source "$CURRENT_DIR/file_helpers.sh"
source "$CURRENT_DIR/save.sh"

# @TODO:
purge_stale_trigger(){
	echo "$FUNCNAME: not implemented"
}

# @TODO:
purge_stale_triggers() {
	echo "$FUNCNAME: not implemented"
}

update_pane_trigger() {
	local pane_id="$1"
	local pane_tty="$(get_pane_tty "$pane_id")"
	local buffer_file_path="$(resurrect_buffer_file "${pane_id}")"
	local history_file_path="$(resurrect_history_file "$pane_id")"
	local trigger_file_path="$(resurrect_trigger_file "$pane_id" "$pane_tty")"
	local timeinsec=$(date +%s)
	local frequency=$(save_auto_frequency) # minutes
	local frequency_sec=$(( $frequency * 60 ))

	# if history/buffer files are missing or one of them is old, update trigger
	local buffer_file_mtime=$( (stat_mtime $buffer_file_path) || echo 0 )
	local buffer_file_staterr=$?
	local history_file_mtime=$( (stat_mtime $history_file_path) || echo 0 )
	local history_file_staterr=$?
	echo "B: $buffer_file_mtime" >> /tmp/tmx.txt
	echo "H: $history_file_mtime" >> /tmp/tmx.txt
	echo "T: $trigger_file_path" >> /tmp/tmx.txt
	if [[ $buffer_file_staterr -ne 0 || $history_file_staterr -ne 0 \
		|| $(( $timeinsec - $buffer_file_mtime )) -gt $frequency_sec \
		|| $(( $timeinsec - $history_file_mtime )) -gt $frequency_sec ]]; then
		touch ${trigger_file_path}
	fi

	return 0
}

# trigger file format: ~/.tmux/resurrect/.trigger-_default:1.1:@dev@pts@0
update_pane_triggers() {
	while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command full_command; do
		update_pane_trigger "$session_name:$window_number.$pane_index"
	done < <(dump_panes)
}

update_state() {
	local state_file_pattern="$(resurrect_dir)/$(resurrect_file_stub)"'*.txt'
	local state_file_path=""
	local timeinsec=$(date +%s)
	local frequency=$(save_auto_frequency) # minutes
	local frequency_sec=$(( $frequency * 60 ))

	# find the most-recent layout/state file
	state_file_path="$(ls -1 $state_file_pattern | sort -r | head -1)"
	[[ $? -ne 0 ]] && return 1

	# calculate age of layout/state file, save state if old or missing
	local state_file_mtime=$( (stat_mtime $state_file_path) || echo 0 )
	local state_file_staterr=$?
	echo "T: $timeinsec" > /tmp/tmx.txt
	echo "M: $state_file_mtime" >> /tmp/tmx.txt
	echo "$(( $timeinsec - $state_file_mtime ))" >> /tmp/tmx.txt
	if [[ $state_file_staterr -ne 0 \
		|| $(( $timeinsec - $state_file_mtime )) -gt $frequency_sec ]]; then
		save_all_states
	fi

	return 0
}

save_all_panes() {
	dump_pane_buffers
}

main() {
	if supported_tmux_version_ok; then
		start_spinner "Auto-save..." "Tmux environment saved!"
		# save all states
		update_state

		# save history/buffer triggers
		update_pane_triggers

		stop_spinner
		display_message "Tmux environment saved!"
	fi
}
main
