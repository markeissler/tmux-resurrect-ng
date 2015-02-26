#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/session_helpers.sh"
source "$CURRENT_DIR/restore_helpers.sh"
source "$CURRENT_DIR/spinner_helpers.sh"

restore_all() {
  local session_name="$1"
  local return_status=0

  [[ -z "$session_name" ]] && return 1

  restore_all_panes "$session_name"
  restore_pane_layout_for_each_window "$session_name" >/dev/null 2>&1
  if enable_pane_history_on; then
    restore_pane_histories "$session_name"
  fi
  if enable_pane_buffers_on; then
    # ttys need to settle after getting cleared
    sleep 2
    restore_pane_buffers "$session_name"
  fi
  restore_all_pane_processes "$session_name"
  # below functions restore exact cursor positions
  restore_active_pane_for_each_window "$session_name"
  restore_zoomed_windows "$session_name"
  restore_active_and_alternate_windows "$session_name"

  return $return_status
}

main() {
  if [[ $(sanity_ok; echo $?) -eq 0 ]]; then
    local session_name="$(get_session_name)"
    local state_file_path="$(last_resurrect_file "$session_name")"
    local versions_str=""
    local restore_rslt version_rslt
    local status_index=0

    #
    # status index
    #   0 - disabled
    #   1 - enabled, pending progress
    #   2 - state restored (not used)
    #   3 - state, buffer, history restored (recovered)
    # 254 - error
    # 255 - fatal
    #

    if [[ $(enable_restore_auto_on; echo $?) -eq 0 ]]; then
      # restore_auto is enabled, bump up status_index
      (( status_index++ ))

      # create restore lock file
      touch "$(restore_lock_file_path "$session_name")"

      # only try to restore if we have a supported state file
      if [[ $(session_state_exists "$session_name"; echo $?) -eq 0 ]]; then
        versions_str="$(resurrect_file_version_ok "$state_file_path")"
        version_rslt=$?

        if [[ "$version_rslt" -ne 0 ]]; then
          local detected_version_str=""
          local supported_versions_str=""
          local message=""
          local display_time="10000" # microseconds!

          # parse detected file format version
          detected_version_str="$(echo "$versions_str" \
            | awk 'BEGIN { FS="],[ ]*" } { print $1; }')"
          detected_version_str="${detected_version_str#[}"
          detected_version_str="${detected_version_str%]}"

          # parse supported file format versions
          supported_versions_str="$(echo "$versions_str" \
            | awk 'BEGIN { FS="],[ ]*" } { print $3; }')"
          supported_versions_str="${supported_versions_str#[}"
          supported_versions_str="${supported_versions_str%]}"

          # display error message
          message="Found: $detected_version_str / Supported: $supported_versions_str"
          display_message "Session state file unsupported! ($message)" "$display_time"

          # return auto restore status code
          status_index=254
        else
          #
          # @TODO: need to check for saved history/buffers too!
          #

          # we have valid state files
          start_spinner "Restoring..."
          sleep 4
          restore_all "$session_name"; restore_rslt=$?
          stop_spinner
          if [[ $restore_rslt -eq 0 ]]; then
            display_message "Auto restore complete!"
            (( status_index+=2 ))
          else
            display_message "Auto restore failed."
            status_index=254
          fi
        fi
      fi

      # remove restore lock file
      rm -f "$(restore_lock_file_path "$session_name")"
    fi
  else
    # tmux version unsupported!
    status_index=255
  fi

  return $status_index
}

main "$@"

# main provides a return value to pass on to caller
exit $?
