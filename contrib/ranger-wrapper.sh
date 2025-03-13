#!/usr/bin/env bash

set -x

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
#
# Output:
# The script should print the selected paths to the output path (argument #5),
# one path per line.
# If nothing is printed, then the operation is assumed to have been canceled.

multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"
cmd="/usr/bin/ranger"
# "wezterm start --always-new-process" if you use wezterm
termcmd="${TERMCMD:-/usr/bin/kitty --title termfilechooser}"

cleanup() {
	if [ -f "$tmpfile" ]; then
		/usr/bin/rm -f "$tmpfile" || :
	fi
	if [ "$save" = "1" ] && [ ! -s "$out" ] && [ -f "$path" ]; then
		/usr/bin/rm "$path" || :
	fi
}

trap cleanup EXIT HUP INT QUIT ABRT TERM

# change this to "/tmp/xxxxxxx/.last_selected" if you only want to save last selected location
# in session (flushed after reset device)
last_selected_path_cfg="${XDG_STATE_HOME:-$HOME/.local/state}/xdg-desktop-portal-termfilechooser/last_selected"
/usr/bin/mkdir -p "$(/usr/bin/dirname "$last_selected_path_cfg")"
if [ ! -f "$last_selected_path_cfg" ]; then
	/usr/bin/touch "$last_selected_path_cfg"
fi
last_selected="$(/usr/bin/cat "$last_selected_path_cfg")"

# Restore last selected path
if [ -d "$last_selected" ]; then
	save_to_file=""
	if [ "$save" = "1" ]; then
		save_to_file="$(/usr/bin/basename "$path")"
		path="${last_selected}/${save_to_file}"
	else
		path="${last_selected}"
	fi
fi
if [ -z "$path" ]; then
	path="$HOME"
fi

if [ "$save" = "1" ]; then
	tmpfile=$(/usr/bin/mktemp)
	# Save/download file
	/usr/bin/printf '%s' 'xdg-desktop-portal-termfilechooser saving files tutorial

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!                 === WARNING! ===                 !!!
!!! The contents of *whatever* file you open last in !!!
!!! ranger will be *overwritten*!                    !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Instructions:
1) Move this file wherever you want.
2) Rename the file if needed.
3) Confirm your selection by opening the file, for
   example by pressing <Enter>.

Notes:
1) This file is provided for your convenience. You can
	 only choose this placeholder file otherwise the save operation aborted.
2) If you quit ranger without opening a file, this file
   will be removed and the save operation aborted.
' >"$path"
	set -- --choosefile="$tmpfile" --cmd="echo Select save path (see tutorial in preview pane; try pressing zv or zp if no preview)" --selectfile="$path"
elif [ "$directory" = "1" ]; then
	# upload files from a directory
	set -- --choosedir="$out" --show-only-dirs --cmd="echo Select directory (quit in dir to select it)" "$path"
elif [ "$multiple" = "1" ]; then
	# upload multiple files
	set -- --choosefiles="$out" --cmd="echo Select file(s) (open file to select it; <Space> to select multiple)" "$path"
else
	# upload only 1 file
	set -- --choosefile="$out" --cmd="echo Select file (open file to select it)" "$path"
fi
$termcmd -- $cmd "$@"

# case save file
if [ "$save" = "1" ] && [ -s "$tmpfile" ]; then
	selected_file=$(/usr/bin/head -n 1 "$tmpfile")
	# Check if selected file is placeholder file
	if [ -f "$selected_file" ] && /usr/bin/grep -qi "^xdg-desktop-portal-termfilechooser saving files tutorial" "$selected_file"; then
		/usr/bin/cat "$tmpfile" >"$out"
	fi
fi

# Saving last selected directory, even when save = 1 and selected file isn't valid placeholder file.
if [ -s "$tmpfile" ] || [ -s "$out" ]; then
	if [ -s "$out" ]; then
		selected_path=$(head -n 1 <"$out")
	elif [ -s "$tmpfile" ]; then
		selected_path=$(head -n 1 <"$tmpfile")
	fi
	if [ -d "$selected_path" ]; then
		echo "$selected_path" >"$last_selected_path_cfg"
	elif [ -f "$selected_path" ]; then
		dirname "$selected_path" >"$last_selected_path_cfg"
	fi
fi
