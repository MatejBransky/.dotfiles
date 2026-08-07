# Prompt configuration:
# The `PS1` variable in Zsh defines the primary command prompt string, which is what you see at the start of each new command line.
# This string can contain special formatting sequences (also called "escape sequences") that Zsh interprets to display useful information.
# In this case, we have the following structure:
#
# '%~ %# '
#
# 1. `%~` : This sequence shows the current working directory (cwd) in a simplified form.
#    - If the current directory is within your home directory, it is represented as `~` followed by the relative path.
#      For example, if your home directory is `/Users/<user>`, and you are in `/Users/<user>/Developer/project-a`,
#      it will display as `~/Developer/project-a`.
#    - If the current directory is not inside your home, it displays the full path.
#    - This allows you to always know where you are in the filesystem in a compact and readable way, without the need for the full path unless required.
#
# 2. `%#` : This sequence displays a symbol that indicates whether you are a regular user or the superuser (root).
#    - If you're a regular user, the symbol will be `%`.
#    - If you're running as the superuser (root), it will change to `#`, letting you know you're working with elevated privileges.
#    - This visual cue helps ensure you are aware of when you're in a session with root access to avoid accidental changes to critical files.
#
# 3. ' ' (space): This is just a space character added at the end of the prompt for better readability.
#    - It separates the prompt symbol from the command you'll type, making the interface cleaner.
#
# Example:
#    - When you're in your home directory, say `/Users/<user>/Developer/project-a`, the prompt will look like this:
#      `~/Developer/project-a % ` (if you're a regular user).
#    - If you're running as root, and you're in `/root`, it will look like this:
#      `/root # `, signaling that you're using superuser privileges.
#
# This prompt is designed to be minimalistic but informative, showing only the necessary context: your location in the file system and
# whether you're working with normal or superuser privileges.
PS1='%~ %# '
