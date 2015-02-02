#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/file_helpers.sh"
source "$CURRENT_DIR/pane_helpers.sh"
source "$CURRENT_DIR/save_helpers.sh"

# @TODO:
purge_stale_trigger(){
	echo "$FUNCNAME: not implemented"
}

# @TODO:
purge_stale_triggers() {
	echo "$FUNCNAME: not implemented"
}

save_all_states() {
	local resurrect_file_path="$(resurrect_file_path)"
	mkdir -p "$(resurrect_dir)"
	dump_panes   >  "$resurrect_file_path"
	dump_windows >> "$resurrect_file_path"
	dump_state   >> "$resurrect_file_path"
	ln -fs "$(basename "$resurrect_file_path")" "$(last_resurrect_file)"
	restore_zoomed_windows
}

update_pane_trigger() {
	local pane_id="$1"
	local pane_tty="$(get_pane_tty "$pane_id")"
	local buffer_file_pattern="$(pane_buffer_file_path "${pane_id}" "true")"
	local buffer_file_path_list=()
	local buffer_file_path=""
	local buffer_file_extension=".txt"
	local history_file_pattern="$(pane_history_file_path "${pane_id}" "true")"
	local history_file_extension=".txt"
	local history_file_path=""
	local trigger_file_path="$(pane_trigger_file "$pane_id" "$pane_tty")"
	local timeinsec=$(date +%s)
	local frequency=$(save_auto_frequency) # minutes
	local frequency_sec=$(( frequency * 60 ))
	local return_status=0

	# must have a pane_id!
	[[ -z "$pane_tty" ]] && return 255

	# figure out buffer file extension
	if [[ $(enable_pane_ansi_buffers_on; echo $?) -eq 0 ]]; then
		buffer_file_extension=".ans"
	fi
	buffer_file_pattern+="$buffer_file_extension"

	# figure out history file extension
	if [[ "$(get_pane_command)" == "bash" ]]; then
		history_file_extension=".bsh"
	fi
	history_file_pattern+="$history_file_extension"

	# find the most-recent buffer file
	IFS=$'\n'
	stderr_status=$(ls -1 $buffer_file_pattern 2>&1 1>/dev/null)
	[[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
	buffer_file_path_list=( $(ls -1 $buffer_file_pattern 2>/dev/null) )
	buffer_file_path=$(echo "${buffer_file_path_list[*]}" | sort -r | head -1)
	IFS="$defaultIFS"

	# find the most-recent history file
	IFS=$'\n'
	stderr_status=$(ls -1 $history_file_pattern 2>&1 1>/dev/null)
	[[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
	history_file_path_list=( $(ls -1 $history_file_pattern 2>/dev/null) )
	history_file_path=$(echo "${history_file_path_list[*]}" | sort -r | head -1)
	IFS="$defaultIFS"

	# if history/buffer files are missing or one of them is old, update trigger
	local buffer_file_mtime=$( (stat_mtime $buffer_file_path) || echo -1 )
	local buffer_file_staterr=0
	local history_file_mtime=$( (stat_mtime $history_file_path) || echo -1 )
	local history_file_staterr=0
	[[ $buffer_file_mtime -lt 0 ]] && buffer_file_staterr=1
	[[ $history_file_mtime -lt 0 ]] && history_file_staterr=1

	# Status reflected in tmux status bar is always behind by one check.
	#
	if [[ $buffer_file_staterr -ne 0 || $history_file_staterr -ne 0 ]]; then
		# no history OR buffer file exists
		return_status=2
	elif [[ $(( timeinsec - buffer_file_mtime )) -gt $frequency_sec \
		|| $(( timeinsec - history_file_mtime )) -gt $frequency_sec ]]; then
		# stale history OR buffer file exists
		return_status=1
	fi

	# save updated history/buffers files if no files exist or files are stale
	if [[ $(enable_debug_mode_on; echo $?) -eq 0 ]]; then
		local debug_file_path="/tmp/tmxr_${pane_id}:${pane_tty//\//@}.txt"
		echo "     time_now: $timeinsec" > "$debug_file_path"
		echo " buffer_mtime: $buffer_file_mtime" >> "$debug_file_path"
		echo "   buffer_age: $(( timeinsec - buffer_file_mtime ))" >> "$debug_file_path"
		echo "  buffer_path: $buffer_file_path" >> "$debug_file_path"
		echo "history_mtime: $history_file_mtime" >> "$debug_file_path"
		echo "  history_age: $(( timeinsec - history_file_mtime ))" >> "$debug_file_path"
		echo " history_path: $history_file_path" >> "$debug_file_path"
		echo " trigger_path: $trigger_file_path" >> "$debug_file_path"
		echo "  update_code: $return_status" >> "$debug_file_path"
	fi
	[[ $return_status -gt 0 ]] && touch "${trigger_file_path}"

	return $return_status
}

update_pane_triggers() {
	local return_status=0

	while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command full_command; do
		update_pane_trigger "$session_name:$window_number.$pane_index"
		local rslt=$?
		[[ $rslt -gt $return_status ]] && return_status=$rslt
	done < <(dump_panes)

	return $return_status
}

update_state() {
	local state_file_pattern="$(resurrect_dir)/$(resurrect_file_stub)"'*.txt'
	local state_file_path_list=()
	local state_file_path=""
	local timeinsec=$(date +%s)
	local frequency=$(save_auto_frequency) # minutes
	local frequency_sec=$(( frequency * 60 ))
	local defaultIFS="$IFS"
	local IFS="$defaultIFS"
	local return_status=0
	local stderr_status=0

	# find the most-recent layout/state file
	IFS=$'\n'
	stderr_status=$(ls -1 $state_file_pattern 2>&1 1>/dev/null)
	[[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
	state_file_path_list=( $(ls -1 $state_file_pattern 2>/dev/null) )
	state_file_path=$(echo "${state_file_path_list[*]}" | sort -r | head -1)
	IFS="$defaultIFS"

	# calculate age of layout/state file, save state if old or missing
	local state_file_mtime=$( (stat_mtime $state_file_path) || echo -1 )
	local state_file_staterr=0
	[[ $state_file_mtime -lt 0 ]] && state_file_staterr=1

	# Status reflected in tmux status bar is always behind by one check.
	#
	if [[ $state_file_staterr -ne 0 ]]; then
		# no state file exists
		return_status=2
	elif [[ $(( timeinsec - state_file_mtime )) -gt $frequency_sec ]]; then
		# stale state file exists
		return_status=1
	fi

	# save updated state if no file exists or file is stale
	if [[ $(enable_debug_mode_on; echo $?) -eq 0 ]]; then
		local session_name="$(get_session_name)"
		local debug_file_path="/tmp/tmxr_${session_name}.txt"
		echo "   time_now: $timeinsec" > "$debug_file_path"
		echo "state_mtime: $state_file_mtime" >> "$debug_file_path"
		echo "  state_age: $(( timeinsec - state_file_mtime ))" >> "$debug_file_path"
		echo "update_code: $return_status" >> "$debug_file_path"
	fi
	[[ $return_status -gt 0 ]] && save_all_states

	return $return_status
}

main() {
	if supported_tmux_version_ok; then
		local state_rslt trigger_rslt purge_state_rslt
		local status_index=0
		local status_codes=( 'X' '-' 'S' 'R' )

		if [[ $(enable_save_auto_on; echo $?) -eq 0 ]]; then
			# save_auto is enabled, bump up status_index
			(( status_index++ ))

			# save all states
			update_state; state_rslt=$?

			# save history/buffer triggers
			update_pane_triggers; trigger_rslt=$?

			# return auto save status code
			[[ $state_rslt -eq 0 ]] && (( status_index++ ))
			[[ $status_index -eq 2 && $trigger_rslt -eq 0 ]] && (( status_index++ ))
		fi

		if [[ $(enable_file_purge_on; echo $?) -eq 0 && $status_index -eq 3 ]]; then
				# purge old states
				purge_state_files; purge_state_rslt=$?
		fi

		printf "%c\n" ${status_codes[$status_index]};
	fi
}
main
