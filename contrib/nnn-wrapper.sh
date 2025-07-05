#!/usr/bin/env bash

if [[ "$6" == "1" ]]; then
  set -x
fi
# This wrapper script is invoked by xdg-desktop-portal-termfilechooser.
#
# Inputs:
# 1. "1" if multiple files can be chosen, "0" otherwise.
# 2. "1" if a directory should be chosen, "0" otherwise.
# 3. "0" if opening files was requested, "1" if writing to a file was
#    requested. For example, when uploading files in Firefox, this will be "0".
#    When saving a web page in Firefox, this will be "1".
# 4. If writing to a file, this is recommended path provided by the caller. For
#    example, when saving a web page in Firefox, this will be the recommended
#    path Firefox provided, such as "~/Downloads/webpage_title.html".
#    Note that if the path already exists, we keep appending "_" to it until we
#    get a path that does not exist.
# 5. The output path, to which results should be written.
# 6. "1" if log level >= DEBUG, "0" otherwise.
#

cleanup() {
  if [ -f "$tmpfile" ]; then
    /usr/bin/rm "$tmpfile" || :
  fi
  if [ "$save" = "1" ] && [ ! -s "$out" ]; then
    /usr/bin/rm "$path" || :
  fi
}
trap cleanup EXIT HUP INT QUIT ABRT TERM

multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"
cmd="/usr/bin/nnn"
if [ "$save" = "1" ]; then
  TITLE="Save File:"
elif [ "$directory" = "1" ]; then
  TITLE="Select Directory:"
else
  TITLE="Select File:"
fi

quote_string() {
  local input="$1"
  echo "'${input//\'/\'\\\'\'}'"
}

termcmd="${TERMCMD:-/usr/bin/kitty --title $(quote_string "$TITLE")}"
# See also: https://github.com/jarun/nnn/wiki/Basic-use-cases#file-picker

# nnn has no equivalent of ranger's:
# `--cmd`
# .. and no other way to show a message text on startup. So, no way to show instructions in nnn itself, like it is done in ranger-wrapper.
# nnn also does not show previews (needs a plugin and a keypress). So, the save instructions in `$path` file are not shown automatically.
# `--show-only-dirs`
# `--choosedir`
# - To select then upload all files in a folder: Go inside of the folder then quit.

if [ "$save" = "1" ]; then
  tmpfile=$(/usr/bin/mktemp)

  # Save/download file
  /usr/bin/printf '%s' 'xdg-desktop-portal-termfilechooser saving files tutorial

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!                 === WARNING! ===                 !!!
!!! The contents of *whatever* file you open last in !!!
!!! yazi will be *overwritten*!                    !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Instructions:
1) Move this file wherever you want.
2) Rename the file if needed.
3) Confirm your selection by opening the file, for
   example by pressing <Enter>.

Notes:
1) This file is provided for your convenience. You can
	 only choose this placeholder file otherwise the save operation aborted.
2) If you quit yazi without opening a file, this file
   will be removed and the save operation aborted.
' >"$path"
  # -a create new FIFO, -P to show preview if they exist
  # Ref: https://github.com/jarun/nnn/wiki/Live-previews
  set -- -p "$(quote_string "$tmpfile")" "$(quote_string "$path")"
elif [ "$directory" = "1" ]; then
  # data will has the format: `cd '/absolute/path/to/folder'`
  tmpfile=$(/usr/bin/mktemp)
  set -- "$(quote_string "$path")"
else
  set -- -p "$(quote_string "$out")" "$(quote_string "$path")"
fi

if [ "$directory" = "1" ]; then
  NNN_TMPFILE="$tmpfile" eval "$termcmd -- $cmd $@"
else
  eval "$termcmd -- $cmd $@"
fi

if [ "$directory" = "1" ] && [ -s "$tmpfile" ]; then
  # convert from `cd '/absolute/path/to/folder'` to `/absolute/path/to/folder`
  selected_dir=$(/usr/bin/head -n 1 "$tmpfile")
  selected_dir="${selected_dir#cd \'}"
  selected_dir="${selected_dir%\'}"
  /usr/bin/echo "$selected_dir" >"$out"
fi

# case save file
if [ "$save" = "1" ] && [ -s "$tmpfile" ]; then
  selected_file=$(/usr/bin/head -n 1 "$tmpfile")
  # Check if selected file is placeholder file
  if [ -f "$selected_file" ] && /usr/bin/grep -qi "^xdg-desktop-portal-termfilechooser saving files tutorial" "$selected_file"; then
    /usr/bin/echo "$selected_file" >"$out"
    path="$selected_file"
  fi
fi
