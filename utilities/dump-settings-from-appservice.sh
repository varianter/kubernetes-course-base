#!/bin/bash
# This script downloads all secrets from an Azure App Service and dumps them to a YAML file.
# The output format matches the input format expected by add-secrets-to-keyvault.sh

# Usage: ./dump-secrets-from-keyvault.sh <app-service-name> <output-file-path>

set -e

# Check if required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <app-service-name> <output-file-path> <resource-group-name>"
    exit 1
fi

APP_SERVICE_NAME=$1
OUTPUT_FILE_PATH=$2.secret
RG_NAME=$3

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install with: brew install jq"
    exit 1
fi

echo "Reading secrets from App Service: $APP_SERVICE_NAME"
echo "Output file: $OUTPUT_FILE_PATH"

# Start the YAML file
echo "settings:" > "$OUTPUT_FILE_PATH"

# Get all secret names from the App Service
SETTING_NAMES=$(az webapp config appsettings list --name "$APP_SERVICE_NAME" --resource-group "$RG_NAME" --query "[].name" -o tsv)

if [ -z "$SETTING_NAMES" ]; then
    echo "Warning: No settings found in App Service '$APP_SERVICE_NAME'"
    exit 0
fi

# Loop through each secret and get its value
while IFS= read -r SETTING_NAME; do
    echo "Downloading secret: $SETTING_NAME"
    
    # Get the setting value:
    SETTING_VALUE=$(az webapp config appsettings list --name "$APP_SERVICE_NAME" --resource-group "$RG_NAME" --query "[?name=='$SETTING_NAME'].value" -o tsv)
    
    # Append to YAML file (name is the same as secretKey for this dump)
    cat >> "$OUTPUT_FILE_PATH" << EOF
  - name: $SETTING_NAME
    secretKey: $SETTING_NAME
    value: "$SETTING_VALUE"
EOF
done <<< "$SETTING_NAMES"

echo "✓ All settings dumped successfully to $OUTPUT_FILE_PATH"
