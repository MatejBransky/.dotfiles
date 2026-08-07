alias slice="pnpm nx g @ataccama/nx-utils:slice"
alias sap="pnpm start:nocheck"
alias pap="pnpm playwright test --config=apps/one-fe-e2e/playwright.config.ts"
alias pwrap="pnpm exec playwright show-report apps/one-fe-e2e/output/html-report"
alias sdt="pnpm nx serve storybook-dt"
alias pdt="pnpm nx playwright-test storybook-dt"
alias tdt-mmm="pnpm tsc --project libs/dt/integrations/mmm/tsconfig.lib.json --noEmit"
alias tmmm-trans="pnpm tsc --project libs/mmm/modules/transformations/tsconfig.lib.json --noEmit"
alias ldt-mmm="pnpm nx lint dt-integration-mmm"
alias lmmm-trans="pnpm nx lint mmm-modules-transformations"
alias fdt-mmm="pnpm nx format:write dt-integration-mmm"
alias fmmm-trans="pnpm nx format:write mmm-modules-transformations"

# Alias 'atalog' processes JSON input using 'jq'.
# It attempts to parse each line of input as JSON. If the input is valid JSON, it removes the 'stack_trace' field 
# and outputs the remaining JSON. The 'stack_trace' information is preserved as a separate string, 
# which can span multiple lines for better readability. If parsing fails, it outputs the original line unchanged.
# Example usage: 
# echo '{"message": "Error occurred", "stack_trace": "at line 1"}' | atalog
# Output:
# {"message": "Error occurred"}
# stack_trace: at line 1
alias atalog="jq -rR '. as \$line | try (fromjson | del(.stack_trace) , .stack_trace) catch \$line'"

export OPENAI_API_BASE=https://api.githubcopilot.com

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
