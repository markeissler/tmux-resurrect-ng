# save_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#   pane_helpers.sh
#

pane_format() {
  local delimiter=$'\t'
  local format
  format+="pane"
  format+="${delimiter}"
  format+="#{session_name}"
  format+="${delimiter}"
  format+="#{window_index}"
  format+="${delimiter}"
  format+=":#{window_name}"
  format+="${delimiter}"
  format+="#{window_active}"
  format+="${delimiter}"
  format+=":#{window_flags}"
  format+="${delimiter}"
  format+="#{pane_index}"
  format+="${delimiter}"
  format+=":#{pane_current_path}"
  format+="${delimiter}"
  format+="#{pane_active}"
  format+="${delimiter}"
  format+="#{pane_current_command}"
  format+="${delimiter}"
  format+="#{pane_pid}"
  echo "$format"
}

window_format() {
  local delimiter=$'\t'
  local format
  format+="window"
  format+="${delimiter}"
  format+="#{session_name}"
  format+="${delimiter}"
  format+="#{window_index}"
  format+="${delimiter}"
  format+="#{window_active}"
  format+="${delimiter}"
  format+=":#{window_flags}"
  format+="${delimiter}"
  format+="#{window_layout}"
  echo "$format"
}

state_format() {
  local delimiter=$'\t'
  local format
  format+="state"
  format+="${delimiter}"
  format+="#{client_session}"
  format+="${delimiter}"
  format+="#{client_last_session}"
  echo "$format"
}

version_format() {
  local delimiter=$'\t'
  local format
  format+="vers"
  format+="${delimiter}"
  format+="$(tmxr_version)"
  echo "$format"
}

dump_panes_raw() {
  tmux list-panes -a -F "$(pane_format)"
}

# translates pane pid to process command running inside a pane
dump_panes() {
  local full_command
  local d=$'\t' # delimiter
  dump_panes_raw |
    while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command pane_pid; do
      # check if current pane is part of a maximized window and if the pane is active
      if [[ "${window_flags}" == *Z* ]] && [[ ${pane_active} == 1 ]]; then
        # unmaximize the pane
        tmux resize-pane -Z -t "${session_name}:${window_number}"
      fi
      full_command="$(full_command $pane_pid)"
      echo "${line_type}${d}${session_name}${d}${window_number}${d}${window_name}${d}${window_active}${d}${window_flags}${d}${pane_index}${d}${dir}${d}${pane_active}${d}${pane_command}${d}:${full_command}"
    done
}

dump_windows() {
  tmux list-windows -a -F "$(window_format)"
}

dump_state() {
  tmux display-message -p "$(state_format)"
}

dump_version() {
  echo "$(version_format)"
}

dump_pane_histories() {
  local target_pane_id="$1"
  local state_file_path_link="$(last_resurrect_file)"
  local state_file_path_link_rslv="" # resolved file link path
  local timestamp=""
  local tmxr_dump_flag=false

  # tmxr_runner will set this flag to true, no one else should
  [[ -n "$2" ]] && tmxr_dump_flag="$2"

  # resolve the file path link
  state_file_path_link_rslv="$(readlink -n $state_file_path_link)"

  # get timestamp from last state file
  if [[ $? -eq 0 ]]; then
    timestamp="$(find_timestamp_from_file "$state_file_path_link_rslv")"
  fi

  dump_panes |
    while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command full_command; do
      local pane_id="$session_name:$window_number.$pane_index"
      [[ -n "$target_pane_id" && "$pane_id" != "$target_pane_id" ]] && continue
      save_pane_history "$pane_id" "$pane_command" "$full_command" "$tmxr_dump_flag" "$timestamp"
    done
}

dump_pane_buffers() {
  local target_pane_id="$1"
  local state_file_path_link="$(last_resurrect_file)"
  local state_file_path_link_rslv="" # resolved file link path
  local timestamp=""
  local tmxr_dump_flag=false

  # tmxr_runner will set this flag to true, no one else should
  [[ -n "$2" ]] && tmxr_dump_flag="$2"

  # resolve the file path link
  state_file_path_link_rslv="$(readlink -n $state_file_path_link)"

  # get timestamp from last state file
  if [[ $? -eq 0 ]]; then
    timestamp="$(find_timestamp_from_file "$state_file_path_link_rslv")"
  fi

  dump_panes |
    while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command full_command; do
      local pane_id="$session_name:$window_number.$pane_index"
      [[ -n "$target_pane_id" && "$pane_id" != "$target_pane_id" ]] && continue
      save_pane_buffer "$pane_id" "$pane_command" "$full_command" "$tmxr_dump_flag" "$timestamp"
    done
}

_purge_files() {
  local file_pattern="$1"
  local frequency="$2" # max files to keep
  local file_path_list=()
  local file_path_list_sorted=()
  local file_path=""
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # we need both of our parameters to function!
  [[ -z "$file_pattern" || -z "$frequency" ]] && return 254

  # find the most-recent files up to frequency (max)
  IFS=$'\n'
  stderr_status=$(ls -1 $file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  file_path_list=( $(ls -1 $file_pattern 2>/dev/null) )
  file_path_list_sorted=( $(echo "${file_path_list[*]}" | sort -r) )
  IFS="$defaultIFS"

  # iterate over path list, skipping frequency count, deleting the rest
  _count=0
  for file in "${file_path_list_sorted[@]}"; do
    (( _count++ ))
    [[ ${_count} -le ${frequency} ]] && continue
    rm "$file"
    [[ $? -ne 0 ]] && return_status=1 && break
  done

  return $return_status
}

purge_buffer_files() {
  local pane_id="$1"
  local buffer_file_pattern="$(pane_buffer_file_path "${pane_id}" "true")"
  local frequency=$(file_purge_frequency) # max files to keep
  local return_status=0

  # must have a pane_id!
  [[ -z "$pane_id" ]] && return 255

  # NOTE: We do not care about the file extension because the buffer files
  # are dependent upon their associated state files. If we delete the state
  # file, then we no longer need the buffer file, regardless of type.
  buffer_file_pattern+='.*'

  _purge_files "$buffer_file_pattern" "$frequency"
  return_status=$?

  return $return_status
}

purge_history_files() {
  local pane_id="$1"
  local history_file_pattern="$(pane_history_file_path "${pane_id}" "true")"
  local frequency=$(file_purge_frequency) # max files to keep
  local return_status=0

  # must have a pane_id!
  [[ -z "$pane_id" ]] && return 255

  # NOTE: We do not care about the file extension because the history files
  # are dependent upon their associated state files. If we delete the state
  # file, then we no longer need the history file, regardless of type.
  history_file_pattern+='.*'

  _purge_files "$history_file_pattern" "$frequency"
  return_status=$?

  return $return_status
}

purge_state_files() {
  local state_file_pattern="$(resurrect_file_path "true")"
  local frequency=$(file_purge_frequency) # max files to keep
  local return_status=0

  _purge_files "$state_file_pattern" "$frequency"
  return_status=$?

  return $return_status
}

purge_all_files() {
  local return_status=0
  local purge_state_rslt

  # purge old states
  purge_state_files; purge_state_rslt=$?
  if [[ $purge_state_rslt -ne 0 ]]; then
    return_status=$purge_state_rslt
  else
    while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command full_command; do
      local pane_id="$session_name:$window_number.$pane_index"
      local rslt

      # purge old buffer files
      purge_buffer_files "$pane_id"; rslt=$?
      [[ $rslt -gt $return_status ]] && return_status=$rslt && break

      # purge old history files
      purge_history_files "$pane_id"; rslt=$?
      [[ $rslt -gt $return_status ]] && return_status=$rslt && break
    done < <(dump_panes)
  fi

  return $return_status
}

save_pane_history() {
  local pane_id="$1"
  local pane_command="$2"
  local full_command="$3"
  local timestamp="$5"
  local tmxr_dump_flag=false
  local history_file_path="$(pane_history_file_path "$pane_id" "false" "$timestamp")"
  local history_file_extension=".txt"
  local update_status=0

  # tmxr_runner will set this flag to true, no one else should
  [[ -n "$4" ]] && tmxr_dump_flag="$4"

  # figure out history file extension
  if [[ "$pane_command" == "bash" ]]; then
    history_file_extension=".bsh"
  fi
  history_file_path+="$history_file_extension"

  # When a pane's prompt_runner calls dump_pane_histories and dump_pane_buffers,
  # the pane_full_command will appear as a login shell (e.g. :-bash) without an
  # argument. This is because prompt_runner calls a bash function (tmxr_runner).
  #
  # When panes are dumped without prompt_runner, we a state file is written, the
  # pane_full_command will be empty (":", just a colon) when a pane is idling at
  # a shell prompt.
  #
  if [ "$pane_command" = "bash" ]; then
    if [[ "$tmxr_dump_flag" = true  && "$full_command" = ":-bash" ]]; then
      # If tmxr_dump_flag is true, the history command is intended to be run
      # from a local function within the target pane. Likely PROMPT_COMMAND.
      history -w "$history_file_path"

      update_status=1
    elif [ "$full_command" = ":" ]; then
      # leading space prevents the command from being saved to history
      # (assuming default HISTCONTROL settings)
      local write_command=" history -w \"$history_file_path\""
      # C-e C-u is a Bash shortcut sequence to clear whole line. It is necessary to
      # delete any pending input so it does not interfere with our history command.
      tmux send-keys -t "$pane_id" C-e C-u "$write_command" C-m

      update_status=1
    fi
  fi

  # relink last to current file
  if [[ "$update_status" -eq 1 ]]; then
    ln -fs "$(basename "$history_file_path")" "$(last_pane_history_file "$pane_id")"
  fi
}

save_pane_buffer() {
  local pane_id="$1"
  local pane_command="$2"
  local full_command="$3"
  local timestamp="$5"
  local tmxr_dump_flag=false
  local buffer_file_path="$(pane_buffer_file_path "${pane_id}" "false" "$timestamp")"
  local buffer_file_extension=".txt"
  local prompt1 prompt2
  local prompt_len=0
  local sed_pattern=""
  local update_status=0

  # tmxr_runner will set this flag to true, no one else should
  [[ -n "$4" ]] && tmxr_dump_flag="$4"

  # figure out buffer file extension
  if [[ $(enable_pane_ansi_buffers_on; echo $?) -eq 0 ]]; then
    buffer_file_extension=".ans"
  fi
  buffer_file_path+="$buffer_file_extension"

  # When a pane's prompt_runner calls dump_pane_histories and dump_pane_buffers,
  # the pane_full_command will appear as a login shell (e.g. :-bash) without an
  # argument. This is because prompt_runner calls a bash function (tmxr_runner).
  #
  # When panes are dumped without prompt_runner, we a state file is written, the
  # pane_full_command will be empty (":", just a colon) when a pane is idling at
  # a shell prompt.
  #
  if [[ "$pane_command" = "bash" ]]; then
    if [[ "$full_command" = ":" \
      || ( "$tmxr_dump_flag" = true && "$full_command" = ":-bash" ) ]]; then
      # adjust tmux capture options
      local capture_color_opt=""
      local ansi_buffer_reset=""
      if enable_pane_ansi_buffers_on; then
        capture_color_opt="-e "
        ansi_buffer_reset=$'\e[0m' # buffer sometimes ends on a color!
      fi
      tmux capture-pane ${capture_color_opt} -t "${pane_id}" -S -32768 \; save-buffer -b 0 "${buffer_file_path}" \; delete-buffer -b 0

      # strip trailing empty lines from saved buffer
      local _filecontent=$(<"${buffer_file_path}")
      printf "%s%b\n" "${_filecontent/$'\n'}" "$ansi_buffer_reset" > "${buffer_file_path}.bak"
      if [[ $? -eq 0 ]]; then
        cp "${buffer_file_path}.bak" "$buffer_file_path"
      fi
      rm "${buffer_file_path}.bak" &> /dev/null
      unset _filecontent

      if [[ "$tmxr_dump_flag" = false ]]; then
        # calculate line span of bash prompt
        #
        # We use an interactive bash shell to grab a baseline count, then run the
        # process again with a carriage return. The difference is the prompt span.
        #
        # NOTE: We do not rely on PS1 here because it could involve expansions.
        #
        prompt1=$( (echo '';) | bash -i 2>&1 | sed -n '$=')
        prompt2=$( (echo $'\n') | bash -i 2>&1 | sed -n '$=')
        (( prompt_len=prompt2-prompt1 ))

        #  add another prompt_len to account for the "history" command execution
        (( prompt_len+=prompt_len ))


        # strip history command and next trailing prompt
        if [ $prompt_len -gt 0 ]; then
          sed_pattern='1,'${prompt_len}'!{P;N;D;};N;ba'
          sed -i.bak -n -e ':a' -e "${sed_pattern}" "${buffer_file_path}" &>/dev/null
        fi
      fi

      rm "${buffer_file_path}.bak" &> /dev/null

      update_status=1
    fi
  fi

  # relink last to current file
  if [[ "$update_status" -eq 1 ]]; then
    ln -fs "$(basename "$buffer_file_path")" "$(last_pane_buffer_file "$pane_id")"
  fi
}
