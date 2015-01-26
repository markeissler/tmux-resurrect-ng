#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# source "$CURRENT_DIR/variables.sh"
# source "$CURRENT_DIR/helpers.sh"
# source "$CURRENT_DIR/spinner_helpers.sh"
source "$CURRENT_DIR/file_helpers.sh"
source "$CURRENT_DIR/save.sh"

debug=1

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
	local return_status=0

	# if history/buffer files are missing or one of them is old, update trigger
	local buffer_file_mtime=$( (stat_mtime $buffer_file_path) || echo 0 )
	local buffer_file_staterr=$?
	local history_file_mtime=$( (stat_mtime $history_file_path) || echo 0 )
	local history_file_staterr=$?

	# Status reflected in tmux status bar is always behind by one check.
	#
	if [[ $buffer_file_staterr -ne 0 || $history_file_staterr -ne 0 ]]; then
		# no history OR buffer file exists
		return_status=-2
	elif [[ $(( $timeinsec - $buffer_file_mtime )) -gt $frequency_sec \
		|| $(( $timeinsec - $history_file_mtime )) -gt $frequency_sec ]]; then
		# stale history OR buffer file exists
		return_status=-1
	fi

	# save updated history/buffers files if no files exist or files are stale
	if [ $debug -ne 0 ]; then
		local debug_file_path="/tmp/tmxr_${pane_id}:${pane_tty//\//@}.txt"
		echo "    	time_now: $timeinsec" > $debug_file_path
		echo " buffer_mtime: $buffer_file_mtime" > $debug_file_path
		echo "   buffer_age: $(( $timeinsec - $buffer_file_mtime ))" >> $debug_file_path
		echo "history_mtime: $history_file_mtime" >> $debug_file_path
		echo "  history_age: $(( $timeinsec - $history_file_mtime ))" >> $debug_file_path
		echo " trigger_path: $trigger_file_path" >> $debug_file_path
		echo "  update_code: $return_status" >> $debug_file_path
	fi
	[[ $return_status -lt 0 ]] && touch ${trigger_file_path}

	return $return_status
}

update_pane_triggers() {
	local return_status=0

	while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command full_command; do
		update_pane_trigger "$session_name:$window_number.$pane_index"
		[[ $? -lt $return_status ]] && return_status=$?
	done < <(dump_panes)

	return $return_status
}

update_state() {
	local state_file_pattern="$(resurrect_dir)/$(resurrect_file_stub)"'*.txt'
	local state_file_path=""
	local timeinsec=$(date +%s)
	local frequency=$(save_auto_frequency) # minutes
	local frequency_sec=$(( $frequency * 60 ))
	local return_status=0

	# find the most-recent layout/state file
	state_file_path="$(ls -1 $state_file_pattern | sort -r | head -1)"
	[[ $? -ne 0 ]] && return -129

	# calculate age of layout/state file, save state if old or missing
	local state_file_mtime=$( (stat_mtime $state_file_path) || echo 0 )
	local state_file_staterr=$?

	# Status reflected in tmux status bar is always behind by one check.
	#
	if [[ $stat_file_staterr -ne 0 ]]; then
		# no state file exists
		return_status=-2
	elif [[ $(( $timeinsec - $state_file_mtime )) -gt $frequency_sec ]]; then
		# stale state file exists
		return_status=-1
	fi

	# save updated state if no file exists or file is stale
	if [ $debug -ne 0 ]; then
		local debug_file_path="/tmp/tmxr_${pane_id%%:*}.txt"
		echo "   time_now: $timeinsec" > $debug_file_path
		echo "state_mtime: $state_file_mtime" >> $debug_file_path
		echo "  state_age: $(( $timeinsec - $state_file_mtime ))" >> $debug_file_path
		echo "update_code: $return_status" >> $debug_file_path
	fi
	[[ $return_status -lt 0 ]] && save_all_states

	return $return_status
}

save_all_panes() {
	dump_pane_buffers
}

main() {
	if supported_tmux_version_ok; then
		local state_rslt trigger_rslt
		local status_index=0
		local status_codes=( '-' 'S' 'R' )

		# save all states
		update_state; state_rslt=$?

		# save history/buffer triggers
		update_pane_triggers; trigger_rslt=$?

		# return auto save status code
		[[ $state_rslt -eq 0 ]] && (( status_index++ ))
		[[ $status_index -eq 2 && $trigger_rslt -eq 0 ]] && (( status_index++ ))
		printf "%c\n" ${status_codes[$status_index]};
	fi
}
main
