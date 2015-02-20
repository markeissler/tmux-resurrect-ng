#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/restore_helpers.sh"
source "$CURRENT_DIR/spinner_helpers.sh"

restore_all() {
  restore_all_panes
  restore_pane_layout_for_each_window >/dev/null 2>&1
  if enable_pane_history_on; then
    restore_pane_histories
  fi
  if enable_pane_buffers_on; then
    # ttys need to settle after getting cleared
    sleep 2
    restore_pane_buffers
  fi
  restore_all_pane_processes
  # below functions restore exact cursor positions
  restore_active_pane_for_each_window
  restore_zoomed_windows
  restore_active_and_alternate_windows
  restore_active_and_alternate_sessions
}

main() {
  if [[ $(sanity_ok; echo $?) -eq 0 ]]; then
    local state_file_path="$(last_resurrect_file)"
    local versions_str=""
    local restore_rslt version_rslt
    local status_index=0

    #
    # status index
    #   0 - disabled (not used)
    #   1 - pending progress
    #   2 - state restored (not used)
    #   3 - state, buffer, history restored (recovered)
    # 254 - error
    # 255 - fatal
    #

    # restore pending progress, bump up status_index
    (( status_index++ ))

    if [[ $(check_saved_session_exists; echo $?) -eq 0 ]]; then
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
        restore_all; restore_rslt=$?
        stop_spinner
        if [[ $restore_rslt -eq 0 ]]; then
          display_message "Restore complete!"
          (( status_index+=2 ))
        else
          display_message "Restore failed."
          status_index=254
        fi
      fi
    fi
  else
    # tmux version unsupported!
    status_index=255
  fi

  # @TODO: We can't return an exit code of anything but 0.
  # Tmux will display any exit code other than 0.
  status_index=0

  return $status_index
}

main "$@"

# main provides a return value to pass on to caller
exit $?
