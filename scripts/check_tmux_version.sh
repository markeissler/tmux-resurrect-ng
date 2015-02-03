#!/usr/bin/env bash

get_tmux_option() {
  local option=$1
  local default_value=$2
  local option_value=$(tmux show-option -gqv "$option")
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

get_tmux_version() {
  echo "$(tmux -V)"
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

# this is used to get "clean" integer version number. Examples:
# `tmux 1.9` => `19`
# `1.9a`     => `19`
get_digits_from_string() {
  local string="$1"
  local only_digits="$(echo "$string" | tr -dC '[:digit:]')"
  echo "$only_digits"
}

exit_if_unsupported_version() {
  local current_version="$1"
  local current_version_int=0
  local supported_version_list=()
  local supported_version_found=0
  local supported_version_last=0 # minimum (last) supported version
  local unsupported_msg="$3"

  # we need a current version and supported version list!
  [[ -z "$1" || -z "$2" ]] && exit 255

  current_version_int="$(get_digits_from_string "$current_version")"
  supported_version_list=( $(echo "${2}" | sort -r | uniq) )

  for version in "${supported_version_list[@]}"; do
    local version_int="$(get_digits_from_string "$version")"
    [[ -z "$version_int" ]] && break

    supported_version_last="$version"
    if [[ $version_int -eq $current_version_int ]]; then
      supported_version_found="$version"
      break
    fi
  done

  if [[ $supported_version_found -eq 0 ]]; then
    local versions_str="${supported_version_list[*]}"
    versions_str="${versions_str// /, }"
    local msg="Installed: $current_version / Required: $versions_str"
    if [[ -n "$unsupported_msg" ]]; then
      display_message "$unsupported_msg ($msg)"
    else
      display_message "Resurrect Error: Tmux version unsupported! ($msg)"
    fi
    exit 1
  fi
}

main() {
  local supported_version_list="$1"
  local unsupported_msg="$2"
  local current_version="$(get_tmux_version)"

  exit_if_unsupported_version "$current_version" "$supported_version_list" "$unsupported_msg"
}

main "$@"
