#!/bin/bash
# This script uploads secrets from environment variable files to an Azure Key Vault.
# It reads a yml file containing the secrets, their desired keys and the values. 

# Sample format:
# secrets:
#   - name: SOME_SECRET
#     secretKey: myapp-instrumentationkey
#     value: "<the value>"
#   - name: ANOTHER_SECRET
#     secretKey: myapp-another-secret
#     value: "<the value>"

# The script PUTs each secretkey into keyvault inferred from $1. Let the value be the value.
# Usage: bin/put-secrets-in-keyvault.sh <key-vault-name> <env-file-path>

set -e

# Check if required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <key-vault-name> <env-file-path>"
    exit 1
fi

KEY_VAULT_NAME=$1
ENV_FILE_PATH=$2

# Check if the env file exists
if [ ! -f "$ENV_FILE_PATH" ]; then
    echo "Error: File '$ENV_FILE_PATH' not found"
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed. Install with: brew install yq"
    exit 1
fi

echo "Reading secrets from $ENV_FILE_PATH"
echo "Uploading to Key Vault: $KEY_VAULT_NAME"

# Read secrets from YAML and upload to Key Vault
yq eval '.secrets[]' "$ENV_FILE_PATH" -o=json | jq -c '.' | while read -r secret; do
    SECRET_KEY=$(echo "$secret" | jq -r '.secretKey')
    SECRET_VALUE=$(echo "$secret" | jq -r '.value')
    SECRET_NAME=$(echo "$secret" | jq -r '.name')
    
    echo "Uploading secret: $SECRET_KEY (for $SECRET_NAME)"
    # Defensively, check if secret exists. If it exists prompt the user to confirm overwrite
    if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$SECRET_KEY" &> /dev/null; then
        read -p "Secret '$SECRET_KEY' already exists in Key Vault. Overwrite? (y/n): " choice </dev/tty
        case "$choice" in
            y|Y ) echo "Overwriting...";;
            n|N ) echo "Skipping '$SECRET_KEY'."; continue;;
            * ) echo "Invalid choice. Skipping '$SECRET_KEY'."; continue;;
        esac
    fi
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "$SECRET_KEY" \
        --value "$SECRET_VALUE" \
        --output none
done

echo "✓ All secrets uploaded successfully"