# helpers.sh
#
# requires:
#		variables.sh
#

default_resurrect_dir="$HOME/.tmux/resurrect"
resurrect_dir_option="@resurrect-dir"

SUPPORTED_VERSION="1.9"

##
# tmux helpers
##

get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

get_session_name() {
	tmux display-message -p "#S"
}

get_pane_id() {
	tmux display-message -p "#S:#I.#P"
}

get_pane_tty() {
	local pane_id="$1"
	[[ -z "$1" ]] && pane_id="$(get_pane_id)"

	# display tty for pane_id
	tmux display-message -t "$pane_id" -p "#{pane_tty}"
}

# Ensures a message is displayed for 5 seconds in tmux prompt.
# Does not override the 'display-time' tmux option.
display_message() {
	local message="$1"

	# display_duration defaults to 5 seconds, if not passed as an argument
	if [ "$#" -eq 2 ]; then
		local display_duration="$2"
	else
		local display_duration="5000"
	fi

	# saves user-set 'display-time' option
	local saved_display_time=$(get_tmux_option "display-time" "750")

	# sets message display time to 5 seconds
	tmux set-option -gq display-time "$display_duration"

	# displays message
	tmux display-message "$message"

	# restores original 'display-time' value
	tmux set-option -gq display-time "$saved_display_time"
}

##
# option helpers
##

enable_debug_mode_on() {
	local option="$(get_tmux_option "$enable_debug_mode_option" "$default_enable_debug_mode")"
	[ "$option" == "on" ]
}

save_auto_frequency() {
	local frequency="$(get_tmux_option "$save_auto_frequency_option" "$default_save_auto_frequency")"
	[[ $frequency -ne 0 && $frequency -lt 5 ]] && frequency="5"
	echo "$frequency"
}

enable_save_auto_on() {
	[ "$(save_auto_frequency)" -ne 0 ]
}

enable_bash_history_on() {
	local option="$(get_tmux_option "$enable_bash_history_option" "$default_enable_bash_history")"
	local optdep="$(get_tmux_option "$dep_enable_bash_history_option" "")"
	[[ -n "$optdep" && "$optdep" == "on" ]] || [ "$option" == "on" ]
}

enable_pane_buffers_on() {
	local option="$(get_tmux_option "$enable_pane_buffers_option" "$default_enable_pane_buffers")"
	local optdep="$(get_tmux_option "$dep_enable_pane_buffers_option" "")"
	[[ -n "$optdep" && "$optdep" == "on" ]] || [ "$option" == "on" ]
}

enable_pane_ansi_buffers_on() {
	local option="$(get_tmux_option "$enable_pane_ansi_buffers_option" "$default_enable_pane_ansi_buffers")"
	local optdep="$(get_tmux_option "$dep_enable_pane_ansi_buffers_option" "")"
	[[ -n "$optdep" && "$optdep" == "on" ]] || [ "$option" == "on" ]
}

##
# path helpers
##

resurrect_dir() {
	echo $(get_tmux_option "$resurrect_dir_option" "$default_resurrect_dir")
}

resurrect_file_stub() {
	local format
	format+="tmux_resurrect_"
	echo "$format"
}

resurrect_file_path() {
	local timestamp="$(date +"%Y-%m-%dT%H:%M:%S")"
	echo "$(resurrect_dir)/$(resurrect_file_stub)${timestamp}.txt"
}

last_resurrect_file() {
	echo "$(resurrect_dir)/last"
}

resurrect_history_file() {
	local pane_id="$1"
	echo "$(resurrect_dir)/bash_history-${pane_id}"
}

resurrect_buffer_file() {
	local pane_id="$1"
	echo "$(resurrect_dir)/tmux_buffer-${pane_id}"
}

resurrect_trigger_file() {
	local pane_id="$1"
	local pane_tty="${2//\//@}"
	echo "$(resurrect_dir)/.trigger-${pane_id}:${pane_tty}"
}

##
# miscellaneous helpers
##
supported_tmux_version_ok() {
	$CURRENT_DIR/check_tmux_version.sh "$SUPPORTED_VERSION"
}

remove_first_char() {
	echo "$1" | cut -c2-
}

restore_zoomed_windows() {
	awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $6 ~ /Z/ && $9 == 1 { print $2, $3; }' $(last_resurrect_file) |
		while IFS=$'\t' read session_name window_number; do
			tmux resize-pane -t "${session_name}:${window_number}" -Z
		done
}
