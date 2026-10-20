#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# Argument / environment variable parsing and command dispatch
#
# Precedence: command-line flag > environment variable > (empty)
# ---------------------------------------------------------------------------

INSTANCE_ID=""
CLIENT_ID=""
CLIENT_SECRET=""
API_KEY=""
TOKEN=""
ENDPOINT=""

# --- Command and its arguments -----------------------------------------------
COMMAND=""          # get-token | upload-bar | create-ir | upload-configuration
CMD_OUTPUT_FILE=""  # get token
CMD_BAR_NAME=""     # upload bar
CMD_BAR_URL_OUTPUT_FILE=""  # upload bar (optional)
CMD_BAR_URL=""      # create ir
CMD_IR_NAME=""      # create ir
CMD_FILE_NAME=""    # upload bar / upload configuration
CMD_CONFIG_NAMES=() # create ir (optional, variadic)
CMD_CFG_NAME=""     # upload configuration
CMD_CFG_TYPE=""     # upload configuration
CMD_CFG_DESC=""     # upload configuration

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] COMMAND [ARGS]

Options:
  --instance-id   <value>   App Connect instance ID      (env: APPCON_INSTANCE_ID)
  --client-id     <value>   SaaS client ID               (env: APPCON_CLIENT_ID)
  --client-secret <value>   SaaS client secret           (env: APPCON_CLIENT_SECRET)
  --api-key       <value>   API key                      (env: APPCON_API_KEY)
  --token         <value>   Bearer token                 (env: APPCON_TOKEN)
  --endpoint      <value>   API endpoint URL             (env: APPCON_ENDPOINT)
  -h, --help                Show this help message

Commands:
  create ir <ir-name> <bar-url> [configuration-name ...]
      Create an Integration Runtime, associating it with a BAR and
      optionally one or more configuration names.

  get token <output-file>
      Retrieve a SaaS token and write it to <output-file>.

  upload bar <bar-name> <file> [bar-url-output-file]
      Upload a BAR file to the instance.
      If <bar-url-output-file> is provided, the returned BAR URL is written to that file.

  upload configuration <config-name> <config-type> <config-description> <file>
      Upload a configuration artifact of the specified type.
EOF
}

# ---------------------------------------------------------------------------
# Command functions
# ---------------------------------------------------------------------------

cmd_get_token() {
    # $CMD_OUTPUT_FILE is set by the parser
    if [[ -z "${CLIENT_ID}" ]]; then
        echo "Error: a client ID is required for 'get token' (use --client-id or set APPCON_CLIENT_ID)" >&2
        exit 1
    fi
    if [[ -z "${CLIENT_SECRET}" ]]; then
        echo "Error: a client secret is required for 'get token' (use --client-secret or set APPCON_CLIENT_SECRET)" >&2
        exit 1
    fi
    if [[ -z "${API_KEY}" ]]; then
        echo "Error: an API key is required for 'get token' (use --api-key or set APPCON_API_KEY)" >&2
        exit 1
    fi
    
    echo "########################################################################"
    echo "# Acquiring token using API key"
    echo "########################################################################" && echo
    set -e # Ensure we fail on error
    curl -s --request POST \
        --url https://${ENDPOINT}/api/v1/tokens \
        --header "X-IBM-Client-Id: ${CLIENT_ID}" \
        --header "X-IBM-Client-Secret: ${CLIENT_SECRET}" \
        --header 'accept: application/json' \
        --header 'content-type: application/json' \
        --header "x-ibm-instance-id: ${INSTANCE_ID}" \
        --data "{\"apiKey\": \"${API_KEY}\"}" --output /tmp/token-output.txt -w "%{http_code}\n" 
    # Avoid using jq as it might not be available
    export TOKEN_OUTPUT=$(cat /tmp/token-output.txt  | tr -d '{}"' | tr ',' '\n' | grep access_token | sed 's/access_token://g')
    if [[ -z "${TOKEN_OUTPUT}" ]]; then
        echo "Error: failed to acquire token" >&2
        cat /tmp/token-output.txt ; echo
        exit 1
    fi
    set +e
    echo $TOKEN_OUTPUT > "${CMD_OUTPUT_FILE}"
    echo "get token succeeded; token placed in ${CMD_OUTPUT_FILE}"
}

cmd_upload_bar() {
    # $CMD_BAR_NAME, $CMD_FILE_NAME are set by the parser
    if [[ -z "${CLIENT_ID}" ]]; then
        echo "Error: a client ID is required for 'upload bar' (use --client-id or set APPCON_CLIENT_ID)" >&2
        exit 1
    fi
    if [[ -z "${TOKEN}" ]]; then
        echo "Error: a token is required for 'upload bar' (use --token or set APPCON_TOKEN)" >&2
        exit 1
    fi

    echo "########################################################################"
    echo "# PUTting BAR file to ACE service"
    echo "########################################################################" && echo
    set -e # Ensure we fail on error
    curl -s -X PUT https://${ENDPOINT}/api/v1/bar-files/${CMD_BAR_NAME} \
        -H "x-ibm-instance-id: ${INSTANCE_ID}" -H "Content-Type: application/octet-stream" \
        -H "Accept: application/json" -H "X-IBM-Client-Id: ${CLIENT_ID}" -H "authorization: Bearer ${TOKEN}" \
        --data-binary @${CMD_FILE_NAME}  --output /tmp/curl-output.txt -w "%{http_code}\n" 
    
    # We will have exited if curl returned non-zero so the output should contain the BAR file name
    #cat /tmp/curl-output.txt ; echo
    # This would be easier with jq but that's not available in most ACE images
    export BARURL=$(cat /tmp/curl-output.txt | tr -d '{}"' | tr ',' '\n' | grep url | sed 's/url://g')
    set +e
    echo "upload bar succeeded; BAR url is ${BARURL}"
    if [[ -n "${CMD_BAR_URL_OUTPUT_FILE}" ]]; then
        echo "${BARURL}" > "${CMD_BAR_URL_OUTPUT_FILE}"
        echo "BAR url written to ${CMD_BAR_URL_OUTPUT_FILE}"
    fi
}

cmd_create_ir() {
    # $CMD_IR_NAME, $CMD_BAR_URL, and $CMD_CONFIG_NAMES[] are set by the parser
    if [[ -z "${CLIENT_ID}" ]]; then
        echo "Error: a client ID is required for 'create ir' (use --client-id or set APPCON_CLIENT_ID)" >&2
        exit 1
    fi
    if [[ -z "${TOKEN}" ]]; then
        echo "Error: a token is required for 'create ir' (use --token or set APPCON_TOKEN)" >&2
        exit 1
    fi
    local config_names_csv=""
    if [[ ${#CMD_CONFIG_NAMES[@]} -gt 0 ]]; then
        local quoted=()
        for name in "${CMD_CONFIG_NAMES[@]}"; do
            quoted+=("\"${name}\"")
        done
        # Join the quoted entries with ", "
        config_names_csv=$(IFS=','; echo "${quoted[*]}")
    fi

    #echo "create ir: ir-name='${CMD_IR_NAME}' bar-url='${CMD_BAR_URL}'"
    #echo "  configuration names csv: ${config_names_csv}"

    
    local json_body
    json_body=$(cat <<EOF
{
    "metadata": { "name": "${CMD_IR_NAME}" },
    "spec": {
        "template": { "spec": { "containers": [ { "name": "runtime" } ] } },
        "barURL": [ "${CMD_BAR_URL}"],
        "configurations": [ ${config_names_csv} ],
        "forceFlowBasicAuth": { "enabled": true },
        "version": "13.0",
        "replicas": 1
    }
}
EOF
)

    echo "${json_body}" > /tmp/curl-input.txt
    
    curl -s -X PUT https://${ENDPOINT}/api/v1/integration-runtimes/${CMD_IR_NAME} \
        -H "x-ibm-instance-id: ${INSTANCE_ID}" -H "Content-Type: application/json" \
        -H "Accept: application/json" -H "X-IBM-Client-Id: ${CLIENT_ID}" -H "authorization: Bearer ${TOKEN}" \
        --data-binary @/tmp/curl-input.txt --output /tmp/curl-output.txt -w "%{http_code}\n" 
}

cmd_upload_configuration() {
    # $CMD_CFG_NAME, $CMD_CFG_TYPE, $CMD_CFG_DESC, $CMD_FILE_NAME are set by the parser
    if [[ -z "${CLIENT_ID}" ]]; then
        echo "Error: a client ID is required for 'upload configuration' (use --client-id or set APPCON_CLIENT_ID)" >&2
        exit 1
    fi
    if [[ -z "${TOKEN}" ]]; then
        echo "Error: a token is required for 'upload configuration' (use --token or set APPCON_TOKEN)" >&2
        exit 1
    fi

    local base64_data
    base64_data=$(base64 < "${CMD_FILE_NAME}" | tr -d '\n')

    local json_body
    json_body=$(cat <<EOF
{
  "metadata": {
    "name": "${CMD_CFG_NAME}"
  },
  "spec": {
    "type": "${CMD_CFG_TYPE}",
    "description": "${CMD_CFG_DESC}",
    "data": "${base64_data}"
  }
}
EOF
)

    echo "${json_body}" > /tmp/curl-input.txt
    
    curl -s -X PUT https://${ENDPOINT}/api/v1/configurations/${CMD_CFG_NAME} \
        -H "x-ibm-instance-id: ${INSTANCE_ID}" -H "Content-Type: application/json" \
        -H "Accept: application/json" -H "X-IBM-Client-Id: ${CLIENT_ID}" -H "authorization: Bearer ${TOKEN}" \
        --data-binary @/tmp/curl-input.txt --output /tmp/curl-output.txt -w "%{http_code}\n" 
}

# --- Parse options (flags that start with --) --------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --instance-id)
            INSTANCE_ID="$2"; shift 2 ;;
        --client-id)
            CLIENT_ID="$2"; shift 2 ;;
        --client-secret)
            CLIENT_SECRET="$2"; shift 2 ;;
        --api-key)
            API_KEY="$2"; shift 2 ;;
        --token)
            TOKEN="$2"; shift 2 ;;
        --endpoint)
            ENDPOINT="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        --*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1 ;;
        *)
            # First non-option token — start of the command
            break ;;
    esac
done

# --- Fall back to environment variables where not set by flags ---------------
INSTANCE_ID="${INSTANCE_ID:-${APPCON_INSTANCE_ID:-}}"
CLIENT_ID="${CLIENT_ID:-${APPCON_CLIENT_ID:-}}"
CLIENT_SECRET="${CLIENT_SECRET:-${APPCON_CLIENT_SECRET:-}}"
API_KEY="${API_KEY:-${APPCON_API_KEY:-}}"
TOKEN="${TOKEN:-${APPCON_TOKEN:-}}"
ENDPOINT="${ENDPOINT:-${APPCON_ENDPOINT:-}}"

# --- Parse command ------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

case "$1" in
    get)
        shift
        if [[ "${1:-}" != "token" ]]; then
            echo "Error: expected 'get token <output-file>', got 'get ${1:-}'" >&2
            usage >&2; exit 1
        fi
        shift
        if [[ $# -lt 1 ]]; then
            echo "Error: 'get token' requires an <output-file> argument" >&2
            usage >&2; exit 1
        fi
        COMMAND="get-token"
        CMD_OUTPUT_FILE="$1"; shift
        ;;

    create)
        shift
        case "${1:-}" in
            ir)
                shift
                if [[ $# -lt 3 ]]; then
                    echo "Error: 'create ir' requires <ir-name> <bar url>" >&2
                    usage >&2; exit 1
                fi
                COMMAND="create-ir"
                CMD_IR_NAME="$1";   shift
                CMD_BAR_URL="$1";  shift
                # Remaining args are optional configuration names
                CMD_CONFIG_NAMES=("$@"); set --
                ;;
                
            *)
                echo "Error: unknown create sub-command '${1:-}'" >&2
                usage >&2; exit 1
                ;;
        esac
        ;;

    upload)
        shift
        case "${1:-}" in
            bar)
                shift
                if [[ $# -lt 2 ]]; then
                    echo "Error: 'upload bar' requires <bar-name> and <file name>" >&2
                    usage >&2; exit 1
                fi
                COMMAND="upload-bar"
                CMD_BAR_NAME="$1"; shift
                CMD_FILE_NAME="$1"; shift
                CMD_BAR_URL_OUTPUT_FILE="${1:-}"; [[ $# -gt 0 ]] && shift
                ;;

            configuration)
                shift
                if [[ $# -lt 4 ]]; then
                    echo "Error: 'upload configuration' requires <config-name> <config-type> <config-description> <file>" >&2
                    usage >&2; exit 1
                fi
                COMMAND="upload-configuration"
                CMD_CFG_NAME="$1"; shift
                CMD_CFG_TYPE="$1"; shift
                CMD_CFG_DESC="$1"; shift
                CMD_FILE_NAME="$1"; shift
                ;;

            *)
                echo "Error: unknown upload sub-command '${1:-}'" >&2
                usage >&2; exit 1
                ;;
        esac
        ;;

    *)
        echo "Error: unknown command '$1'" >&2
        usage >&2; exit 1
        ;;
esac

if [[ -z "${ENDPOINT}" ]]; then
    echo "Error: an endpoint is required for all commands (use --endpoint or set APPCON_ENDPOINT)" >&2
    exit 1
fi
if [[ -z "${INSTANCE_ID}" ]]; then
    echo "Error: an instance ID is required for all commands (use --instance-id or set APPCON_INSTANCE_ID)" >&2
    exit 1
fi
# --- Dispatch ----------------------------------------------------------------
case "${COMMAND}" in
    create-ir)             cmd_create_ir ;;
    get-token)             cmd_get_token ;;
    upload-bar)            cmd_upload_bar ;;
    upload-configuration)  cmd_upload_configuration ;;
esac
