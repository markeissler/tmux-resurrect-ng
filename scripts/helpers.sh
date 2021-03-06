# helpers.sh
#
# requires:
#   variables.sh
#

default_resurrect_dir="$HOME/.tmux/resurrect-ng"
resurrect_dir_option="@resurrect-dir"

##
# tmxr helpers
##

# this version of tmux-resurrect-ng (tmxr)
tmxr_version() {
  echo "$tmxr_version"
}

# versions of tmux-resurrect-ng that this version supports for auto-migrating
# older tmxr file formats to this version.
#
# Returns a space delimited string of records.
#
tmxr_versions_list() {
  printf "%s" "${tmxr_version_list[*]}"
}

# versions of tmux that tmux-resurrect-ng (tmxr) supports
#
# Returns a space delimited string of records.
#
tmux_versions_list() {
  printf "%s" "${tmux_version_list[*]}"
}

##
# tmux helpers
##

# check if tmux server is running, returns 255 on failure
get_tmux_status() {
  local return_status=0
  local result=""

  result="$({ tmux show-option -sqv "buffer-limit"; } 2>&1)"
  [[ $? -ne 0 ]] && return_status=255

  return $return_status
}

get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local option_value=""
  local return_status=0

  option_value="$({ tmux show-option -gqv "$option"; } 2>&1)"
  [[ $? -ne 0 ]] && return_status=255

  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi

  return $return_status
}

get_tmux_version() {
  echo "$(tmux -V)"
}

get_session_name() {
  local session_name="$TMXR_SESSION"
  local return_status=0

  if [[ -z "$session_name" ]]; then
    session_name="$(tmux display-message -p "#S")"
    return_status=1
  fi

  echo "$session_name"; return $return_status
}

set_session_name() {
  local session_name="$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && echo "" && return 1

  TMXR_SESSION="$1"
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

get_pane_command() {
  local pane_id="$1"
  [[ -z "$1" ]] && pane_id="$(get_pane_id)"

  # display current pane command for pane_id
  tmux display-message -t "$pane_id" -p "#{pane_current_command}"
}

get_status_interval() {
  echo $(get_tmux_option "status-interval" "0")
}

# Ensures a message is displayed for 5 seconds in tmux prompt.
# Does not override the 'display-time' tmux option.
display_message() {
  local message="Resurrect: $1"
  local msgicon=">"
  local display_duration=5000 # milliseconds

  # display_duration
  [[ -n "$2" ]] && display_duration="$2"

  # message icon (precedes output of message)
  [[ -n "$3" ]] && msgicon="$3"

  # saves user-set 'display-time' option
  local saved_display_time=$(get_tmux_option "display-time" "750")

  # sets message display time to 5 seconds
  tmux set-option -gq display-time "$display_duration"

  # displays message
  tmux display-message " $msgicon $message"

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

file_purge_frequency() {
  local frequency="$(get_tmux_option "$file_purge_frequency_option" "$default_file_purge_frequency")"
  [[ $frequency -lt 0 ]] && frequency="0"
  echo "$frequency"
}

enable_file_purge_on() {
  [ "$(file_purge_frequency)" -ne 0 ]
}

enable_restore_auto_on() {
  local option="$(get_tmux_option "$enable_restore_auto_option" "$default_enable_restore_auto")"
  [ "$option" == "on" ]
}

save_auto_frequency() {
  local frequency="$(get_tmux_option "$save_auto_frequency_option" "$default_save_auto_frequency")"
  [[ $frequency -lt 0 ]] && frequency="0"
  [[ $frequency -ne 0 && $frequency -lt 5 ]] && frequency="5"
  echo "$frequency"
}

enable_save_auto_on() {
  [ "$(save_auto_frequency)" -ne 0 ]
}

enable_pane_history_on() {
  local option="$(get_tmux_option "$enable_pane_history_option" "$default_enable_pane_history")"
  local optdep="$(get_tmux_option "$dep_enable_pane_history_option" "")"
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
  echo "tmxr_"
}

resurrect_file_path() {
  local session_name="$1"
  local globstamp='[0-9]*'
  local timestamp="$(date +"%s")"

  # must have a session_name!
  [[ -z "$session_name" ]] && echo "" && return 1

  # globstamp instead of timestamp?
  [[ -n "$2" && "$2" = true ]] && timestamp="$globstamp"

  # caller supplied timestamp?
  [[ -n "$3" && "$2" = false ]] && timestamp="$2"

  echo "$(resurrect_dir)/$(resurrect_file_stub)${timestamp}_sstate-${session_name}.txt"
}

last_resurrect_file() {
  local session_name="$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && echo "" && return 1

  echo "$(resurrect_dir)/last_sstate-${session_name}"
}

restore_lock_file_path() {
  local session_name="$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && echo "" && return 1

  echo "$(resurrect_dir)/.restore-${session_name}"
}

status_runner_file_path() {
  local session_name="$1"
  local globstamp='[0-9]*'
  local timestamp="$(date +"%s")"

  # must have a session_name!
  [[ -z "$session_name" ]] && echo "" && return 1

  # globstamp instead of timestamp?
  [[ -n "$2" && "$2" = true ]] && timestamp="$globstamp"

  # caller supplied timestamp?
  [[ -n "$3" && "$2" = false ]] && timestamp="$3"

  echo "$(resurrect_dir)/.srunner-${session_name}_${timestamp}.run"
}

pane_history_file_path() {
  local pane_id="$1"
  local globstamp='[0-9]*'
  local timestamp="$(date +"%s")"

  # must have a pane_id!
  [[ -z "$pane_id" ]] && echo "" && return 1

  # globstamp instead of timestamp?
  [[ -n "$2" && "$2" = true ]] && timestamp="$globstamp"

  # caller supplied timestamp?
  [[ -n "$3" && "$2" = false ]] && timestamp="$3"

  echo "$(resurrect_dir)/$(resurrect_file_stub)${timestamp}_history-${pane_id}"
}

last_pane_history_file() {
  local pane_id="$1"

  # must have a pane_id!
  [[ -z "$pane_id" ]] && echo "" && return 1

  echo "$(resurrect_dir)/last_history-${pane_id}"
}

pane_buffer_file_path() {
  local pane_id="$1"
  local globstamp='[0-9]*'
  local timestamp="$(date +"%s")"

  # must have a pane_id!
  [[ -z "$pane_id" ]] && echo "" && return 1

  # globstamp instead of timestamp?
  [[ -n "$2" && "$2" = true ]] && timestamp="$globstamp"

  # caller supplied timestamp?
  [[ -n "$3" && "$2" = false ]] && timestamp="$3"

  echo "$(resurrect_dir)/$(resurrect_file_stub)${timestamp}_buffer-${pane_id}"
}

last_pane_buffer_file() {
  local pane_id="$1"

  # must have a pane_id!
  [[ -z "$pane_id" ]] && echo "" && return 1

  echo "$(resurrect_dir)/last_buffer-${pane_id}"
}

pane_actions_file_path() {
  local pane_id="$1"
  local pane_tty="${2//\//@}"

  # must have a pane_id AND pane_tty!
  [[ -z "$pane_id" || -z "$pane_tty" ]] && echo "" && return 1

  echo "$(resurrect_dir)/.actions-${pane_id}:${pane_tty}"
}

pane_trigger_file_path() {
  local pane_id="$1"
  local pane_tty="${2//\//@}"

  # must have a pane_id AND pane_tty!
  [[ -z "$pane_id" || -z "$pane_tty" ]] && echo "" && return 1

  echo "$(resurrect_dir)/.trigger-${pane_id}:${pane_tty}"
}

##
# path name parser helpers
##

# extract the timestamp portion from the filename provided as first arg
find_timestamp_from_file() {
  local file_name="$(basename "$1")"
  local file_timestamp=""
  local file_timestamp_pattern='s/^.*[_]([[:digit:]]{10,})[._].*$/\1/'
  local return_status=0

  # must have a file_name!
  [[ -z "$file_name" ]] && echo "" && return 1

  file_timestamp="$(echo "$file_name" \
    | sed -E -e "$file_timestamp_pattern" -e 'tx' -e 'd' -e ':x')"

  echo -n "$file_timestamp"; return $return_status
}

##
# miscellaneous helpers
##
sanity_ok() {
  local resurrect_dir="$(resurrect_dir)"
  local status_index=0
  local tmxr_runner_flag="${1:-false}"

  #
  # status index
  #   0 - ok
  #   1 - no tmux server
  #   2 - bad tmux version
  #   3 - bad file system
  # 255 - fatal (reserved)
  #

  # is tmux running?
  [[ -z "$TMUX" ]] && status_index=1

  # check tmux version
  #
  # @TODO: check_tmux_version.sh is broken for prompt_runner
  # On startup, the first prompt triggers a call through sanity_ok(), which
  # then ends up calling check_tmux_version.sh. If that script calls the
  # tmux display-message it will fail because a client does  not yet exist.
  if [[ $status_index -eq 0 && "$tmxr_runner_flag" == false ]]; then
    if [[ $(supported_tmux_version_ok; echo $?) -eq 1 ]]; then
      status_index=2
    fi
  fi

  # create resurrect_dir if it doesn't exist
  if [[ $status_index -eq 0 && ! -d "$resurrect_dir" ]]; then
    # tmxr directory, try to recover by creating one
    mkdir -p "$resurrect_dir"
    [[ $? -ne 0 ]] && status_index=3
  fi

  return $status_index
}

supported_tmux_version_ok() {
  "$CURRENT_DIR/check_tmux_version.sh" "$(tmux_versions_list)"
}

resurrect_file_version() {
  local resurrect_file_path="$1"
  local resurrect_file_vers=""
  local return_status=0
  local return_string=""

  [[ ! -f "$resurrect_file_path" ]] && return 255

  resurrect_file_vers="$({ awk 'BEGIN { FS="\t"; OFS="\t" } /^vers/ { print $2; }' "$resurrect_file_path"; } 2> /dev/null)"
  [[ $? -ne 0 ]] && echo "" && return 1

  return_string="${resurrect_file_vers:-unknown}"

  echo -n "$return_string"; return $return_status
}

resurrect_file_version_ok() {
  local resurrect_file_path="$1"
  local resurrect_file_vers=""
  local resurrect_file_places=2 # only compare major.minor from version
  local return_status=0
  local return_string=""

  [[ ! -f "$resurrect_file_path" ]] && return 255

  resurrect_file_vers="$(resurrect_file_version "$resurrect_file_path")"
  [[ $? -ne 0 ]] && echo "" && return 1

  return_string="$(version_in_versionlist "$resurrect_file_vers" "$(tmxr_versions_list)" "$resurrect_file_places")"
  return_status=$?

  echo -n "$return_string"; return $return_status
}

version_in_versionlist() {
  local target_version="$1"
  local target_version_int=0
  local target_places=3
  local version_list=()
  local version_list_match="" # matching version found
  local version_list_sorted=()
  local version_newest""      # newest version in list
  local version_oldest=""     # oldest version in list
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local return_string=""

  IFS=$' ' version_list=( $2 ) IFS="$defaultIFS"

  # match all three places (major.minor.bugfix) by default
  [[ -n "$3" ]] && target_places="$3"

  # we need a target version and version list!
  [[ -z "$target_version" || "${#version_list[@]}" -eq 0 ]] && exit 255

  target_version_int="$(digits_from_string "$target_version" "$target_places")"
  version_list_sorted=( $(printf "%s\n" "${version_list[@]}" | sort -r | uniq) )

  # We iterate over the version list, converting version strings to version ints
  # (the version number stripped of alpha chars and punctuation), and comparing
  # the "int" version list value to the "int" target version value. We save both
  # the first entry and the last entry to establish a range that is returned to
  # our caller.
  local _count=0
  for version in "${version_list_sorted[@]}"; do
    local version_int="$(digits_from_string "$version" "$target_places")"
    [[ -z "$version_int" ]] && break

    [[ $_count -eq 0 ]] && version_newest="$version"
    version_oldest="$version"
    if [[ "$version_int" = "$target_version_int" ]]; then
      version_list_match="$version"
      break
    fi
    (( _count++ ))
  done

  # return_string format:
  #   [target], [oldest, newest], [versions]
  # e.g. not matching
  #   [1.7], [1.9a, 3.2], [1.9a, 2.0, 2.1, 3.0, 3.1, 3.2]
  #
  if [[ -z "$version_list_match" ]]; then
    return_status=1
  fi
  local version_list_string="${version_list_sorted[@]}"
  return_string+="[$target_version]"
  return_string+=", [$version_oldest, $version_newest]"
  return_string+=", [${version_list_string// /, }]"

  echo "$return_string"; return $return_status
}

# this is used to get "clean" integer version number. Examples:
# `tmux 1.9` => `19`
# `1.9a`     => `19`
digits_from_string() {
  local string="$1"
  local string_array=()
  local places=3
  local places_string=""
  local only_digits=""
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"

  [[ -n "$2" ]] && places="$2"

  # trim extraneous places from string
  IFS='.' string_array=( $string ) IFS="$defaultIFS"

  for (( i=0; $i<${#string_array[@]} && $i<$places; i++  )); do
    places_string+="${string_array[i]}"
  done

  only_digits="$(echo "$places_string" | tr -dC '[:digit:]')"

  echo "$only_digits"
}

remove_first_char() {
  echo "${1:1}"
}

restore_zoomed_windows() {
  local session_name="${1:-$(get_session_name)}" # defaults to client session
  local last_state_file="$(last_resurrect_file "$session_name")"

  while IFS=$'\t' read _session_name _window_number; do
    tmux resize-pane -t "${_session_name}:${_window_number}" -Z
  done <<< "$(awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $6 ~ /Z/ && $9 == 1 { print $2, $3; }' "$last_state_file")"
}
