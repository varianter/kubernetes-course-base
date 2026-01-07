#!/bin/bash
# This script downloads all secrets from an Azure Key Vault and dumps them to a YAML file.
# The output format matches the input format expected by add-secrets-to-keyvault.sh

# Usage: ./dump-secrets-from-keyvault.sh <key-vault-name> <output-file-path>

set -e

# Check if required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <key-vault-name> <output-file-path>"
    exit 1
fi

KEY_VAULT_NAME=$1
OUTPUT_FILE_PATH=$2.secret

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install with: brew install jq"
    exit 1
fi

echo "Reading secrets from Key Vault: $KEY_VAULT_NAME"
echo "Output file: $OUTPUT_FILE_PATH"

# Start the YAML file
echo "secrets:" > "$OUTPUT_FILE_PATH"

# Get all secret names from the Key Vault
SECRET_NAMES=$(az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "[].name" -o tsv)

if [ -z "$SECRET_NAMES" ]; then
    echo "Warning: No secrets found in Key Vault '$KEY_VAULT_NAME'"
    exit 0
fi

# Loop through each secret and get its value
while IFS= read -r SECRET_KEY; do
    echo "Downloading secret: $SECRET_KEY"
    
    # Get the secret value
    SECRET_VALUE=$(az keyvault secret show \
        --vault-name "$KEY_VAULT_NAME" \
        --name "$SECRET_KEY" \
        --query "value" -o tsv)
    
    # Append to YAML file (name is the same as secretKey for this dump)
    cat >> "$OUTPUT_FILE_PATH" << EOF
  - name: $SECRET_KEY
    secretKey: $SECRET_KEY
    value: "$SECRET_VALUE"
EOF
done <<< "$SECRET_NAMES"

echo "✓ All secrets dumped successfully to $OUTPUT_FILE_PATH"
