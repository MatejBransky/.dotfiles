# Local PostgreSQL database from Docker Compose (host-side connection).
export DEV_DB_HOST=localhost
export DEV_DB_PORT=5433
export DEV_DB_USER=postgres
export DEV_DB_NAME=ribbon

# Load the dev DB password from Bitwarden only when it is needed.
function dev-db-env() {
  if [[ -z ${BW_SESSION:-} ]]; then
    echo "Run bw-unlock first."
    return 1
  fi

  local password
  password="$(bw get password 'Momence (dev db)')" || return 1
  export DEV_DB_PASSWORD="$password"
  export DEV_DB_URL="postgres://${DEV_DB_USER}:${DEV_DB_PASSWORD}@${DEV_DB_HOST}:${DEV_DB_PORT}/${DEV_DB_NAME}"
}

# Function to perform a DTF sanity check using curl with provided user, password, tenant, and URL.
curldtf() {
  local user password tenant url
  while getopts "U:p:t:" opt; do
    case $opt in
      U) user=$OPTARG ;;
      p) password=$OPTARG ;;
      t) tenant=$OPTARG ;;
      *) echo "Usage: curldtf -U user -p password -t tenant url"; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))
  url=$1

  echo "user=$user"
  echo "password=$password"
  echo "tenant=$tenant"
  echo "url=$url"

  if [[ -z $user || -z $password || -z $tenant || -z $url ]]; then
    echo "Usage: curldtf -U user -p password -t tenant url"
    return 1
  fi

  curl -d '{"query": "query { sanityCheck { success components { component status message } } }"}' \
    -H "Content-Type: application/json" \
    -k \
    -u "$user:$password" \
    -H "Tenant-Id: $tenant" \
    "${url%/}/private/api/dtf/graphql"
}



# ~ init task CLI (~/Developer/work/tools) — runs against source via tsx, no build step needed
alias it="~/Developer/work/tools/apps/init-task/node_modules/.bin/tsx ~/Developer/work/tools/apps/init-task/src/bin.ts"
