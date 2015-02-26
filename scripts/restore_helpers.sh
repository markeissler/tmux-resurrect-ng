# restore_helpers.sh
#
# requires:
#   variables.sh
#   helpers.sh
#   process_restore_helpers.sh
#

is_line_type() {
  local line_type="$1"
  local line="$2"
  echo "$line" |
    \grep -q "^$line_type"
}

check_saved_session_exists() {
  local session_name="$1"
  local resurrect_file_path="$(last_resurrect_file "$session_name")"

  # failed to construct file path!
  [[ $? -ne 0 ]] && return 255

  if [ ! -f $resurrect_file_path ]; then
    return 1
  fi
}

pane_exists() {
  local session_name="$1"
  local window_number="$2"
  local pane_index="$3"

  tmux list-panes -t "${session_name}:${window_number}" -F "#{pane_index}" 2>/dev/null |
    \grep -q "^$pane_index$"
}

window_exists() {
  local session_name="$1"
  local window_number="$2"

  tmux list-windows -t "$session_name" -F "#{window_index}" 2>/dev/null |
    \grep -q "^$window_number$"
}

session_exists() {
  local session_name="$1"

  tmux has-session -t "$session_name" 2>/dev/null
}

first_window_num() {
  tmux show -gv base-index
}

tmux_socket() {
  echo $TMUX | cut -d',' -f1
}

new_window() {
  local session_name="$1"
  local window_number="$2"
  local window_name="$3"
  local dir="$4"

  tmux new-window -d -t "${session_name}:${window_number}" -n "$window_name" -c "$dir"
}

new_session() {
  local session_name="$1"
  local window_number="$2"
  local window_name="$3"
  local dir="$4"

  TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -n "$window_name" -c "$dir"
  # change first window number if necessary
  local created_window_num="$(first_window_num)"
  if [ $created_window_num -ne $window_number ]; then
    tmux move-window -s "${session_name}:${created_window_num}" -t "${session_name}:${window_number}"
  fi
}

new_pane() {
  local session_name="$1"
  local window_number="$2"
  local window_name="$3"
  local dir="$4"

  tmux split-window -t "${session_name}:${window_number}" -c "$dir"
  # minimize window so more panes can fit
  tmux resize-pane  -t "${session_name}:${window_number}" -U "999"
}

restore_pane_for_state() {
  local pane_sstate_record="$1" # a "pane" line from a session state record

  # must have a pane_sstate_record!
  [[ -z "$pane_sstate_record" ]] && return 1

  # while loop local vars! because we are not piping into while
  local line_type session_name dir
  local window_number window_name window_active window_flags
  local pane_index pane_active pane_command pane_full_command
  while IFS=$'\t' read line_type session_name window_number window_name window_active window_flags pane_index dir pane_active pane_command pane_full_command; do
    dir="$(remove_first_char "$dir")"
    window_name="$(remove_first_char "$window_name")"
    pane_full_command="$(remove_first_char "$pane_full_command")"
    if pane_exists "$session_name" "$window_number" "$pane_index"; then
      # Pane exists, no need to create it!
      # Pane existence is registered. Later, it's process also isn't restored.
      register_existing_pane "$session_name" "$window_number" "$pane_index"
    elif window_exists "$session_name" "$window_number"; then
      new_pane "$session_name" "$window_number" "$window_name" "$dir"
    elif session_exists "$session_name"; then
      new_window "$session_name" "$window_number" "$window_name" "$dir"
    else
      new_session "$session_name" "$window_number" "$window_name" "$dir"
    fi
  done < <(echo "$pane_sstate_record")
}

restore_state() {
  local state="$1"

  echo "$state" |
    while IFS=$'\t' read _line_type _client_session _client_last_session; do
      tmux switch-client -t "${_client_last_session}"
      tmux switch-client -t "${_client_session}"
    done
}

restore_all_panes() {
  local session_name="$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && return 1

  # while loop local vars! because we are not piping into while
  local line
  while read line; do
    if is_line_type "pane" "$line"; then
      restore_pane_for_state "$line"
    fi
  done < $(last_resurrect_file "$session_name")
}

restore_pane_history() {
  local pane_id="$1"
  local pane_command="$2"

  # must have a pane_id!
  [[ -z "$pane_id" ]] && return 1

  if [ "$pane_command" = "bash" ]; then
    # tmux send-keys has -R option that should reset the terminal.
    # However, appending 'clear' to the command seems to work more reliably.
    local read_command="history -r '$(last_pane_history_file "$pane_id")'; clear"
    tmux send-keys -t "$pane_id" "$read_command" C-m
  fi
}

restore_pane_histories() {
  local session_name="$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && return 1

  awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ { print $2, $3, $7, $10; }' $(last_resurrect_file "$session_name") |
    while IFS=$'\t' read _session_name _window_number _pane_index _pane_command; do
      local __pane_id="${_session_name}:${_window_number}.${_pane_index}"
      restore_pane_history "${__pane_id}" "${_pane_command}"
    done
}

restore_pane_buffer() {
  local pane_id="$1"
  local pane_command="$2"

  # must have a pane_id!
  [[ -z "$pane_id" ]] && return 1

  if [ "$pane_command" = "bash" ]; then
    local buffer_file_path="$(last_pane_buffer_file "$pane_id")"
    # space before 'cat' is intentional and prevents the command from
    # being added to history (provided HISTCONTROL=ignorespace/ignoreboth
    # has been set in bashrc.
    tmux send-keys -t "$pane_id" " clear && tmux clear-history" C-m
    local pane_tty="$(get_pane_tty "$pane_id")"
    if [ -n "$pane_tty" ]; then
      # append directly to tty (avoids cat command output)
      cat "$buffer_file_path" >> "$pane_tty"
    else
      # fall back to cat'ing in terminal if not tty found
      tmux send-keys -t "$pane_id" " cat \"$buffer_file_path\"" C-m
    fi
  fi
}

restore_pane_buffers() {
  local session_name="$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && return 1

  awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ { print $2, $3, $7, $10; }' $(last_resurrect_file "$session_name") |
    while IFS=$'\t' read _session_name _window_number _pane_index _pane_command; do
      local __pane_id="${_session_name}:${_window_number}.${_pane_index}"
      restore_pane_buffer "${__pane_id}" "${_pane_command}"
    done
}

restore_all_pane_processes() {
  local session_name="$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && return 1

  if restore_pane_processes_enabled; then
    local pane_full_command
    awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $11 !~ "^:$" { print $2, $3, $7, $8, $11; }' $(last_resurrect_file "$session_name") |
      while IFS=$'\t' read _session_name _window_number _pane_index _dir _pane_full_command; do
        _dir="$(remove_first_char "${_dir}")"
        _pane_full_command="$(remove_first_char "${_pane_full_command}")"
        restore_pane_process "${_pane_full_command}" "${_session_name}" "${_window_number}" "${_pane_index}" "${_dir}"
      done
  fi
}

restore_pane_layout_for_each_window() {
  local session_name="$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && return 1

  \grep '^window' $(last_resurrect_file "$session_name") |
    while IFS=$'\t' read _line_type _session_name _window_number _window_active _window_flags _window_layout; do
      tmux select-layout -t "${_session_name}:${_window_number}" "${_window_layout}"
    done
}

restore_active_pane_for_each_window() {
  local session_name"$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && return 1

  awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $9 == 1 { print $2, $3, $7; }' $(last_resurrect_file "$session_name") |
    while IFS=$'\t' read _session_name _window_number _active_pane; do
      tmux switch-client -t "${_session_name}:${_window_number}"
      tmux select-pane -t "${_active_pane}"
    done
}

restore_active_and_alternate_windows() {
  local session_name"$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && return 1

  awk 'BEGIN { FS="\t"; OFS="\t" } /^window/ && $5 ~ /[*-]/ { print $2, $4, $3; }' $(last_resurrect_file "$session_name") |
    sort -u |
    while IFS=$'\t' read _session_name _active_window _window_number; do
      tmux switch-client -t "${_session_name}:${_window_number}"
    done
}

restore_active_and_alternate_sessions() {
  local session_name"$1"

  # must have a session_name!
  [[ -z "$session_name" ]] && return 1

  # while loop local vars! because we are not piping into while
  local line
  while read line; do
    if is_line_type "state" "$line"; then
      restore_state "$line"
    fi
  done < $(last_resurrect_file "$session_name")
}
