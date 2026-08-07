# Define priority constants
PRIORITY_1=1000
PRIORITY_2=800
PRIORITY_3=600
PRIORITY_4=400
PRIORITY_5=200
PRIORITY_6=0

# Initialize the variable to track initialization source
INITIALIZED_BY=''

# Array to hold commands and their priorities as tuples
init_commands=()

# Function to register commands with priorities
# Arguments:
# $1 = command
# $2 = priority
# Usage example `register_command 'echo "Hello World"' 10`
function register_command() {
  init_commands+=("$1:${2:-$PRIORITY_6}") # Store command and priority as a single string
}

# Function to execute sorted commands and set INITIALIZED_BY
function execute_commands_by() {
  INITIALIZED_BY="$1" # Set the source of initialization

  # Sort commands alphabetically and remove priorities
  IFS=$'\n' sorted_commands=($(printf "%s\n" "${init_commands[@]}" | sort | cut -d':' -f1))
  unset IFS

  for cmd in $sorted_commands; do
    # echo "Executed init command: $cmd"
    eval "$cmd" # Execute each command
  done
}
