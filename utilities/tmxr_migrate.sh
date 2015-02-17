#!/usr/bin/env bash
#
# migrate data from tmux-resurrect to tmux-resurrect-ng
#
# This is a one-way operation but all original files are copied into backup
# directory in case they need to be restored. Files that are not recognized are
# neither moved or altered.
#

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/../scripts/variables.sh"
source "$CURRENT_DIR/../scripts/helpers.sh"
source "$CURRENT_DIR/../scripts/file_helpers.sh"

# override runtime resurrect options
#
# Setting "static" parameters allows you to run this script without the tmux
# server running, but will also ignore default resurrect settings or those that
# may have been normally set as a resurrect optin in tmux.conf.
#
# This means that if you set one static parameter, you must set all of them.
#
# While setting file extensions to ".txt" may not impact operation today, this
# is not guaranteed behavior for future releases.
#
# Normally, it is best to leave these settings undefined (commented out) or set
# to zero-length strings.
#

# override the runtime resurrect directory setting
#
# The raw default is "$HOME/.tmux/resurrect".
#
#g_tmxr_directory_static="$HOME/.tmux/resurrect"

# override the runtime resurrect-ng directory setting
#
# The raw default is "$HOME/.tmux/resurrect-ng".
#
#g_tmxr_directory_ng_static="$HOME/.tmux/resurrect-ng"

# override the runtime history file name extension
#
# The raw default is ".ans" since ansi buffers are enabled by default.
#
# .ans (ansi enabled)
# .txt (ansi disabled)
#g_tmxr_buffer_extension_static=".ans"

##############################################################################
###### NO SERVICABLE PARTS BELOW
##############################################################################
g_tmxr_directory="$g_tmxr_directory_static"
g_tmxr_directory_ng="$g_tmxr_directory_ng_static"
g_tmxr_backupdir="$g_tmxr_directory/migrated_files"
# file extensions
g_tmxr_buffer_extension="$g_tmxr_buffer_extension_static"
g_tmxr_history_extension=".bsh" # .bsh (bash), .txt (non-specific shell)
g_tmxr_state_extension=".txt"
#
g_debug=0
g_noise=1

# extract a list of unique pane ids from a list of file paths
find_paneids_from_files() {
  local file_list=()
  local paneid_list=()
  local paneid_list_sorted=()
  local paneid_pattern='s/^.*-([[:alnum:][:punct:]]+:[[:digit:]]+\.[[:digit:]]+)(\.[[:alpha:]]+)*$/\1/'
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0

  IFS=$' ' file_list=( $1 ) IFS="$defaultIFS"

  # we need a file list!
  [[ "${#file_list[@]}" -eq 0 ]] && return 255

  # delete non-matching lines (where substitution fails)
  #   -e 'tx' -e 'd' -e ':x'
  # where...
  #   tx - branches to label x if substitution is successful
  #   d  - deletes line
  #   :x - marker for label 'x'
  #
  # see: http://stackoverflow.com/a/1665662/3321356
  #

  # We iterate over the file list, extracting pane ids from each file name.
  local _file _file_basename _paneid
  for _file in "${file_list[@]}"; do
    _file_basename="$(basename "${_file}")"
    _paneid="$(echo "${_file_basename}" \
      | sed -E -e "$paneid_pattern" -e 'tx' -e 'd' -e ':x')"
    if [[ -n "${_paneid}" ]]; then
      paneid_list+=( "${_paneid}" )
    fi
    _paneid=""
  done
  unset _file _file_basename _paneid

  # sort and dedupe the paneid list
  paneid_list_sorted=( $(printf "%s" "${paneid_list[*]}" | sort -r | uniq) )

  # done!
  printf "%s" "${paneid_list_sorted[*]}"

  return $return_status
}

# old: bash_history-_default:1.1
# new: tmxr_1423010160_history-_default:1.1.bsh
migrate_history_files() {
  local file_pattern="$g_tmxr_directory/bash_history-"'*'
  local file_path_list=()
  local migrated_file_path_list=()
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # get list of files
  IFS=$'\n'
  stderr_status=$(ls -1 $file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  file_path_list=( $(ls -1 $file_pattern 2>/dev/null) )
  IFS="$defaultIFS"

  if [[ "$g_debug" -ne 0 ]]; then
    echo "$stderr_status"
    echo "${#file_path_list}"
  fi

  # iterate over list
  local _count=0
  local _mtime=0
  local _file _file_basename _file_renamed
  for _file in "${file_path_list[@]}"; do
    (( _count++ ))
    _file_basename="$(basename "${_file}")"

    if [[ "$g_debug" -ne 0 ]]; then
      printf "renaming: %s\n" "${_file_basename}"
    fi

    ## get age of file (stat)
    _mtime="$(stat_mtime "${_file}")"

    ## translate old name to new name
    _file_renamed="$(echo "${_file_basename}" \
      | sed -E -e "s/^bash_history-([[:alnum:][:punct:]]+:[[:digit:]]+\.[[:digit:]]+$)/tmxr_${_mtime}_history-\1/")"

    # add extension
    _file_renamed+="$g_tmxr_history_extension"

    if [[ "$g_debug" -ne 0 ]]; then
      printf "     -->: %s\n" "${_file_renamed}"
    fi

    # copy original to renamed file
    cp "${_file}" "${g_tmxr_directory_ng}/${_file_renamed}"
    [[ $? -ne 0 ]] && return_status=1 && break

    # add "${_file}" to completed queue array
    migrated_file_path_list+=( "${g_tmxr_directory_ng}/${_file_renamed}" )

    # copy or move original file to backupdir
    if [[ "$g_tmxr_directory_ng" != "$g_tmxr_directory" ]]; then
      cp "${_file}" "$g_tmxr_backupdir"
    else
      mv "${_file}" "$g_tmxr_backupdir"
    fi
    [[ $? -ne 0 ]] && return_status=1 && break
  done
  unset _file _file_basename _file_renamed

  # return array of migrated files
  if [[ "$g_debug" -eq 0 ]]; then
    printf "%s\n" "${migrated_file_path_list[@]}"
  fi

  return $return_status
}

# old: tmux_buffer-_default:1.1
# new: tmxr_1423010691_buffer-_default:1.1.ans
migrate_buffer_files() {
  local file_pattern="$g_tmxr_directory/tmux_buffer-"'*'
  local file_path_list=()
  local migrated_file_path_list=()
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # get list of files
  IFS=$'\n'
  stderr_status=$(ls -1 $file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  file_path_list=( $(ls -1 $file_pattern 2>/dev/null) )
  IFS="$defaultIFS"

  if [[ "$g_debug" -ne 0 ]]; then
    echo "$stderr_status"
    echo "${#file_path_list}"
  fi

  # iterate over list
  local _count=0
  local _mtime=0
  local _file _file_basename _file_renamed
  for _file in "${file_path_list[@]}"; do
    (( _count++ ))
    _file_basename="$(basename "${_file}")"

    if [[ "$g_debug" -ne 0 ]]; then
      printf "renaming: %s\n" "${_file_basename}"
    fi

    ## get age of file (stat)
    _mtime="$(stat_mtime "${_file}")"

    ## translate old name to new name
    _file_renamed="$(echo "${_file_basename}" \
      | sed -E -e "s/^tmux_buffer-([[:alnum:][:punct:]]+:[[:digit:]]+\.[[:digit:]]+$)/tmxr_${_mtime}_buffer-\1/")"

    # add extension
    _file_renamed+="$g_tmxr_buffer_extension"

    if [[ "$g_debug" -ne 0 ]]; then
      printf "     -->: %s\n" "${_file_renamed}"
    fi

    # copy original to renamed file
    cp "${_file}" "${g_tmxr_directory_ng}/${_file_renamed}"
    [[ $? -ne 0 ]] && return_status=1 && break

    # add "${_file}" to completed queue array
    migrated_file_path_list+=( "${g_tmxr_directory_ng}/${_file_renamed}" )

    # copy or move original file to backupdir
    if [[ "$g_tmxr_directory_ng" != "$g_tmxr_directory" ]]; then
      cp "${_file}" "$g_tmxr_backupdir"
    else
      mv "${_file}" "$g_tmxr_backupdir"
    fi
    [[ $? -ne 0 ]] && return_status=1 && break
  done
  unset _file _file_basename _file_renamed

  # return array of migrated files
  if [[ "$g_debug" -eq 0 ]]; then
    printf "%s\n" "${migrated_file_path_list[@]}"
  fi

  return $return_status
}

# old: tmux_resurrect_2015-02-04T12:43:32.txt
# new: tmxr_1423082426.txt
migrate_state_files() {
  local file_pattern="$g_tmxr_directory/tmux_resurrect_"'*.txt'
  local file_path_list=()
  local file_path_link="$g_tmxr_directory/last"
  local file_path_link_rslv="" # resolved file link path
  local migrated_file_path_list=()
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # get list of files
  IFS=$'\n'
  stderr_status=$(ls -1 $file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  file_path_list=( $(ls -1 $file_pattern 2>/dev/null) )
  IFS="$defaultIFS"

  if [[ "$g_debug" -ne 0 ]]; then
    echo "$stderr_status"
    echo "${#file_path_list}"
  fi

  # iterate over list
  local _count=0
  local _mtime=0
  local _file _file_basename _file_dirname _file_renamed
  for _file in "${file_path_list[@]}"; do
    (( _count++ ))
    _file_basename="$(basename "${_file}")"

    if [[ "$g_debug" -ne 0 ]]; then
      printf "renaming: %s\n" "${_file_basename}"
    fi

    ## get age of file (stat)
    _mtime="$(stat_mtime "${_file}")"

    _file_renamed="$(echo "${_file_basename}" \
      | sed -E -e "s/^tmux_resurrect_([[:alnum:][:punct:]]+\.txt$)/tmxr_${_mtime}/")"

    # add extension
    _file_renamed+="$g_tmxr_state_extension"

    if [[ "$g_debug" -ne 0 ]]; then
      printf "     -->: %s\n" "${_file_renamed}"
    fi

    # copy original to renamed file
    cp "${_file}" "${g_tmxr_directory_ng}/${_file_renamed}"
    [[ $? -ne 0 ]] && return_status=1 && break

    # add "${_file}" to completed queue array
    migrated_file_path_list+=( "${g_tmxr_directory_ng}/${_file_renamed}" )

    # copy or move original file to backupdir
    if [[ "$g_tmxr_directory_ng" != "$g_tmxr_directory" ]]; then
      cp "${_file}" "$g_tmxr_backupdir"
    else
      mv "${_file}" "$g_tmxr_backupdir"
    fi
    [[ $? -ne 0 ]] && return_status=1 && break
  done
  unset _file _file_basename _file_renamed

  if [[ $return_status -eq 0 ]]; then
    # relink last file in backupdir
    file_path_link_rslv="$(readlink -n $file_path_link)"
    if [[ -n "$file_path_link_rslv" ]]; then
      ln -fs "$file_path_link_rslv" "$g_tmxr_backupdir/last"
      # still ok?
      [[ $? -ne 0 ]] && return_status=1
    fi
  fi

  # return array of migrated files
  if [[ "$g_debug" -eq 0 ]]; then
    printf "%s\n" "${migrated_file_path_list[@]}"
  fi

  return $return_status
}

relink_last_files() {
  local state_file_pattern="$g_tmxr_directory_ng/tmxr_[0-9]*"'.txt'
  local state_file_path_list=()
  local state_file_path=""
  local buffer_file_pattern="$g_tmxr_directory_ng/tmxr_[0-9]*_buffer"'*.*'
  local buffer_file_path_list=()
  local buffer_file_path=""
  local history_file_pattern="$g_tmxr_directory_ng/tmxr_[0-9]*_buffer"'*.*'
  local history_file_path_list=()
  local history_file_path=""
  local paneid_list=()
  local file_path_list=()
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local return_status=0
  local stderr_status=0

  # find most-recent state file and link to last
  IFS=$'\n'
  stderr_status=$(ls -1 $state_file_pattern 2>&1 1>/dev/null)
  [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
  state_file_path_list=( $(ls -1 $state_file_pattern 2>/dev/null) )
  state_file_path=$(echo "${state_file_path_list[*]}" | sort -r | head -1)
  IFS="$defaultIFS"

  if [[ -n "$state_file_path" ]]; then
    ln -fs "$(basename "$state_file_path")" "$g_tmxr_directory_ng/last"
    # still ok?
    [[ $? -ne 0 ]] && return_status=1
  fi

  # find all buffer files, and get a list of unique pane ids
  if [[ "$return_status" -eq 0 ]]; then
    IFS=$'\n'
    stderr_status=$(ls -1 $buffer_file_pattern 2>&1 1>/dev/null)
    [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
    buffer_file_path_list=( $(ls -1 $buffer_file_pattern 2>/dev/null) )
    IFS="$defaultIFS"
    paneid_list=( $(find_paneids_from_files "${buffer_file_path_list[*]}") )
  fi

  # iterate over paneid_list and find the most-recent buffer file for each
  if [[ "$return_status" -eq 0 ]]; then
    local _paneid
    local _buffer_file_pattern
    local _buffer_file_path_list=()
    local _buffer_file_path=""
    for _paneid in "${paneid_list[@]}"; do
      _buffer_file_pattern="$g_tmxr_directory_ng/tmxr_[0-9]*_buffer-${_paneid}"'.*'
      IFS=$'\n'
      stderr_status=$(ls -1 ${_buffer_file_pattern} 2>&1 1>/dev/null)
      [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
      _buffer_file_path_list=( $(ls -1 ${_buffer_file_pattern} 2>/dev/null) )
      _buffer_file_path=$(echo "${_buffer_file_path_list[*]}" | sort -r | head -1)
      IFS="$defaultIFS"
      # link to last_buffer-PANE_ID
      ln -fs "$(basename "${_buffer_file_path}")" "$g_tmxr_directory_ng/last_buffer-${_paneid}"
      # still ok?
      [[ $? -ne 0 ]] && return_status=2 && break
    done
    unset _buffer_file_path
    unset _buffer_file_path_list
    unset _buffer_file_pattern
    unset _paneid
  fi

  # iterate over paneid_list and find the most-recent history file for each
    if [[ "$return_status" -eq 0 ]]; then
    local _paneid
    local _history_file_pattern
    local _history_file_path_list=()
    local _history_file_path=""
    for _paneid in "${paneid_list[@]}"; do
      _history_file_pattern="$g_tmxr_directory_ng/tmxr_[0-9]*_history-${_paneid}"'.*'
      IFS=$'\n'
      stderr_status=$(ls -1 ${_history_file_pattern} 2>&1 1>/dev/null)
      [[ $? -ne 0 ]] && [[ ! "${stderr_status}" =~ "No such file or directory" ]] && return 255
      _history_file_path_list=( $(ls -1 ${_history_file_pattern} 2>/dev/null) )
      _history_file_path=$(echo "${_history_file_path_list[*]}" | sort -r | head -1)
      IFS="$defaultIFS"
      # link to last_history-PANE_ID
      ln -fs "$(basename "${_history_file_path}")" "$g_tmxr_directory_ng/last_history-${_paneid}"
      # still ok?
      [[ $? -ne 0 ]] && return_status=3 && break
    done
    unset _history_file_path
    unset _history_file_path_list
    unset _history_file_pattern
    unset _paneid
  fi

  return $return_status
}

remove_files() {
  # remove files in array passed to us
  echo "$FUNCNAME: not implemented"
}

main() {
  local migrated_file_path_list=()
  local defaultIFS="$IFS"
  local IFS="$defaultIFS"
  local status=0
  local static_settings=( \
    "g_tmxr_directory_static" \
    "g_tmxr_directory_ng_static" \
    "g_tmxr_buffer_extension_static" \
  )

  echo "Running tmux-resurrect to tmux-resurrect-ng migration..."

  echo "Checking configuration"

  # check if some, but not all static settings have been set
  local _static_set=0
  for _static_setting in "${static_settings[@]}"; do
    [[ -n "${!_static_setting}" ]] && (( _static_set++ ))
  done
  if [[ ${_static_set} -gt 0 && ${_static_set} -ne ${#static_settings[@]} ]]; then
    printf "\n"
    printf "ERROR: You have set some but not all static settings. Either set all\n"
    printf "       static settings or set none.\n"
    printf "\n"
    printf "The following static settings are available:\n"
    printf "\n"
    printf "       %s\n" "${static_settings[@]}"
    printf "\n"
    printf "Aborting. Migration failed.\n"
    return 1
  fi
  # check if we need tmux server running
  if [[ ${_static_set} -eq 0 ]]; then
    if [[ $(get_tmux_status; echo $?) -ne 0 ]]; then
      printf "\n"
      printf "ERROR: Static settings not specified and tmux server is unreachable.\n"
      printf "       Either set static settings or start tmux server.\n"
      printf "\n"
      printf "Aborting. Migration failed.\n"
      return 1
    fi

    # get tmxr resurrect directory settings
    g_tmxr_directory="$(resurrect_dir)"

    # configure resurrect-ng directory settings
    g_tmxr_directory_ng="${g_tmxr_directory}"

    # handle the old default directory path
    if [[ "$g_tmxr_directory" == "$default_resurrect_dir" ]]; then
      g_tmxr_directory="${g_tmxr_directory%-ng}"
    fi

    # get tmxr buffer extension setting
    if [[ $(enable_pane_ansi_buffers_on; echo $?) -eq 0 ]]; then
      g_tmxr_buffer_extension=".ans"
    else
      g_tmxr_buffer_extension=".txt"
    fi
  fi
  unset _static_set

  # check if tmux resurrect directory is invalid
  if [[ -z "${g_tmxr_directory}" || ! -d "${g_tmxr_directory}" ]]; then
    printf "\n"
    printf "ERROR: Invalid tmux resurrect directory specified.\n"
    printf "\n"
    printf "The following directory setting is configured:\n"
    printf "\n"
    printf "       %s\n" "${g_tmxr_directory}"
    printf "\n"
    printf "Aborting. Migration failed.\n"
    return 1
  fi

  # re-configure backup directory
  g_tmxr_backupdir="$g_tmxr_directory_ng/migrated_files"

  #
  # Behavior differs whether or not the we are migrating within the same dir.
  # The default ng directory is ~/.tmux/resurrect-ng, but the user may have
  # specified a different directory via the @resurrect-dir config setting or
  # with the static setting.
  #
  # As long as the new directory is different from the old directory, we just
  # copy renamed files to the new directory, and copy the old files to the
  # "migrated_files" directory within the new directory; this leaves the old
  # directory pristine. Rolling back just requires deleting the new directory.
  #
  # When the new and old directory are the same (which will always occur if the
  # user has set @resurrect-dir) then we move the old files to the "migrated_
  # files" directory in the new/old directory as we leave renamed copies in the
  # top level of that directory. Rolling back requires deleting all renamed
  # files and copying back all of the old files from the "migrated_files" dir,
  # then removing that directory.
  #
  # To facilitiate the above, all migrate_ functions return a list of renamed
  # files which is appended to the master list of renamed files here.
  #
  # Upon successful completion we will always leave behind a backup directory,
  # the "migrated_files" directory which will be found within the new directory.
  #

  echo "Migrating tmux-resurrect files to tmux-resurrect-ng format..."

  echo "Creating backup directory"
  mkdir -p "$g_tmxr_backupdir"
  [[ $? -ne 0 ]] && status=1

  if [[ $status -eq 0 ]]; then
    if [[ "$g_tmxr_directory_ng" != "$g_tmxr_directory" ]]; then
      echo "Creating resurrect-ng directory"
      mkdir -p "$g_tmxr_directory_ng"
      [[ $? -ne 0 ]] && status=2
    fi
  fi

  if [[ $status -eq 0 ]]; then
    echo "Migrating history files"
    IFS=$'\n'
    migrated_file_path_list+=( $(migrate_history_files) )
    IFS="$defaultIFS"
    [[ $? -ne 0 ]] && status=3
  fi

  if [[ $status -eq 0 ]]; then
    echo "Migrating buffer files"
    IFS=$'\n'
    migrated_file_path_list+=( $(migrate_buffer_files) )
    IFS="$defaultIFS"
    [[ $? -ne 0 ]] && status=4
  fi

  if [[ $status -eq 0 ]]; then
    echo "Migrating state files"
    IFS=$'\n'
    migrated_file_path_list+=( $(migrate_state_files) )
    IFS="$defaultIFS"
    [[ $? -ne 0 ]] && status=5
  fi

  if [[ $status -eq 0 ]]; then
    echo "Relinking last files"
    relink_last_files
    [[ $? -ne 0 ]] && status=6
  fi

  if [[ "$g_debug" -eq 0 && $g_noise -gt 1 ]]; then
    echo "Updated files..."
    for file in "${migrated_file_path_list[@]}"; do
      echo "$file"
    done
  fi

  # remove all migrated files, last links, and migrated backups back into
  # place, then remove resurrect-ng dir if different from original.
  if [[ $status -ne 0 ]]; then
    echo
    echo "Something unplanned for has happened. Rolling back..."

    if [[ "$g_tmxr_directory_ng" != "$g_tmxr_directory" ]]; then
      # updated files moved to a new directory. delete it!
      rm -rf "$g_tmxr_directory_ng"
    else
      # updated files moved to same directory. restore it!
      echo "Removing updated files"
      for file in "${migrated_file_path_list[@]}"; do
        [[ $g_noise -gt 1 ]] && echo "rm: $file"
        rm -f $file
      done
      # remove links
      echo "Removing last links"
      rm -f "$g_tmxr_directory_ng/last"
      rm -f "$g_tmxr_directory_ng/last_buffer-"*
      rm -f "$g_tmxr_directory_ng/last_history-"*
      # restore successfully migrated files
      echo "Restoring backup files"
      cp -Rp "$g_tmxr_backupdir/"* "$g_tmxr_directory"
      # remove migrated_files directory
      echo "Removing backup directory"
      rm -rf "$g_tmxr_backupdir" 2>&1 > /dev/null
    fi
  fi

  if [[ $status -ne 0 ]]; then
    echo
    echo "Tried migrating your files but there were problems."
    echo "Your original files have been restored."
    echo
  else
    echo
    echo "All done! You are ready to use tmux-resurrect-ng!"
    echo
    echo "Updated files are located at:"
    echo
    echo "    $g_tmxr_directory_ng"
    echo
    echo "Your original files have been copied to a backup at:"
    echo
    echo "    $g_tmxr_backupdir"
    echo
    echo "You may want to remove that directory after you feel"
    echo "comfortable with tmux-resurrect-ng."
    echo
  fi

  return $status
}

main "$@"

exit $?
