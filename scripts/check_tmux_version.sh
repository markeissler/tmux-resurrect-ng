#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"

exit_if_unsupported_version() {
  local target_version="$1"
  local version_list=()
  local unsupported_msg="$3"
  local display_time="10000" # microseconds!
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local return_string=""

  IFS=$' ' version_list=( $2 ) IFS="$defaultIFS"

  # we need a target version and version list!
  [[ -z "$target_version" || "${#version_list[@]}" -eq 0 ]] && exit 255

  return_string="$(version_in_versionlist "$target_version" "${version_list[*]}")"
  return_status=$?

  if [[ $(enable_debug_mode_on; echo $?) -eq 0 ]]; then
    echo "target tmux version: $target_version" > /tmp/tmxr_chk_version.txt
    echo " versions supported: ${#version_list[@]}" >> /tmp/tmxr_chk_version.txt
    echo "unsupported message: $unsupported_msg" >> /tmp/tmxr_chk_version.txt
    echo "version ck response: $return_string" >> /tmp/tmxr_chk_version.txt
  fi

  if [[ "$return_status" -ne 0 ]]; then
    local required_versions_str="$(echo "$return_string" \
      | awk 'BEGIN { FS="],[ ]*" } { print $3; }')"
    required_versions_str="${required_versions_str#[}"
    required_versions_str="${required_versions_str%]}"
    local msg="Installed: $target_version / Required: $required_versions_str"
    if [[ -n "$unsupported_msg" ]]; then
      display_message "$unsupported_msg ($msg)" "$display_time"
    else
      display_message "Resurrect: Tmux version unsupported! ($msg)" "$display_time"
    fi
    exit 1
  fi

  return $return_status
}

main() {
  local supported_version_list="$1"
  local unsupported_msg="$2"
  local current_version="$(get_tmux_version)"

  exit_if_unsupported_version "$current_version" "$supported_version_list" "$unsupported_msg"
}

main "$@"
