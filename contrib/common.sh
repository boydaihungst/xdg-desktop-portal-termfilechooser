# Common functions for wrapper scripts for xdg-desktop-portal-termfilechooser.

# Input args and ouptut format of the wrapper scripts:
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


default_termcmd () {
	# Picking the default terminal emulator. Similar to
	# 	https://github.com/i3/i3/blob/next/i3-sensible-terminal
	# The first available command is used.
	wtitle='FileChooser'  # Title text for the terminal window
	term_cmds="
		x-terminal-emulator -e
		wezterm -e
		kitty --title="$wtitle"
		gnome-terminal --title="$wtitle" --wait --
		urxvt -title "$wtitle" -e
		uxterm -title "$wtitle" -e
		xterm -title "$wtitle" -e
		"
	echo "$term_cmds" | while read -r tcmd; do
		if command -v "${tcmd%% *}" > /dev/null 2>&1 ; then
			echo "$tcmd"
			break
		fi
	done
}


create_save_file() {
	path=$1
	out=$2
	cat > "$path" <<-'END'
	xdg-desktop-portal-termfilechooser saving files tutorial

	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!!!                 === WARNING! ===                 !!!
	!!! The contents of *whatever* file you open last in !!!
	!!! file manager will be *overwritten*!              !!!
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	Instructions:
	1) Move this file wherever you want.
	2) Rename the file if needed.
	3) Confirm your selection by opening the file, for
		 example by pressing <Enter>.

	Notes:
	1) This file is provided for your convenience. You
		 could delete it and choose another file to overwrite
		 that, for example.
	2) If you quit file manager without opening a file, this
	   file will be removed and the save operation aborted.
	END
	rm "$out" || : 	# Remove the old /tmp/termfilechooser.portal
	cleanup() {
		# Remove the file with the above tutorial text if the calling program did not overwrite it.
		if [ ! -s "$out" ] || [ "$path" != "$(cat "$out")" ]; then
			rm "$path" || :
		fi
	}
	trap cleanup EXIT HUP INT QUIT ABRT TERM
}
