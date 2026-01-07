#!/bin/bash

# Script to query Azure App Services and Functions
# Outputs information to appservices.md and appservices.csv

OUTPUT_FILE="appservices.md"
CSV_FILE="appservices.csv"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "Querying Azure subscription: $SUBSCRIPTION_NAME"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo ""

# Initialize the markdown file
cat > "$OUTPUT_FILE" << EOF
# Azure App Services and Functions Report

**Subscription:** $SUBSCRIPTION_NAME  
**Subscription ID:** $SUBSCRIPTION_ID  
**Generated:** $(date)

---

EOF

# Initialize the CSV file with headers
cat > "$CSV_FILE" << EOF
Name,Type,Resource Group,Location,SKU/Pricing Tier,SKU Name,Instance Count,Estimated Cost,Microsoft Entra ID Auth,Auth Provider,Portal Link
EOF

# Get all App Services (Web Apps)
echo "Fetching App Services..."
APP_SERVICES=$(az webapp list --query "[].{name:name, resourceGroup:resourceGroup, kind:kind, location:location}" -o json)

# Get all Function Apps
echo "Fetching Function Apps..."
FUNCTION_APPS=$(az functionapp list --query "[].{name:name, resourceGroup:resourceGroup, kind:kind, location:location}" -o json)

# Combine both lists
ALL_APPS=$(jq -s '.[0] + .[1]' <(echo "$APP_SERVICES") <(echo "$FUNCTION_APPS"))

# Count total apps
TOTAL_COUNT=$(echo "$ALL_APPS" | jq 'length')

echo "Found $TOTAL_COUNT app(s)"
echo ""

if [ "$TOTAL_COUNT" -eq 0 ]; then
    echo "## No App Services or Function Apps found" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "No resources found in this subscription." >> "$OUTPUT_FILE"
else
    echo "## Summary" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Total App Services and Function Apps: **$TOTAL_COUNT**" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "---" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Process each app
    COUNTER=1
    echo "$ALL_APPS" | jq -c '.[]' | while IFS= read -r app; do
        APP_NAME=$(echo "$app" | jq -r '.name')
        RESOURCE_GROUP=$(echo "$app" | jq -r '.resourceGroup')
        KIND=$(echo "$app" | jq -r '.kind')
        LOCATION=$(echo "$app" | jq -r '.location')
        
        echo "Processing [$COUNTER/$TOTAL_COUNT]: $APP_NAME"
        
        # Determine app type
        if [[ "$KIND" == *"functionapp"* ]]; then
            APP_TYPE="Function App"
        else
            APP_TYPE="App Service"
        fi
        
        # Get authentication settings
        AUTH_ENABLED="No"
        AUTH_PROVIDER="None"
        
        AUTH_SETTINGS=$(az webapp auth show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            AUTH_ENABLED_FLAG=$(echo "$AUTH_SETTINGS" | jq -r '.enabled // false')
            
            if [ "$AUTH_ENABLED_FLAG" = "true" ]; then
                AUTH_ENABLED="✅ Yes"
                
                # Check for Microsoft Entra ID (Azure AD) provider
                AAD_ENABLED=$(echo "$AUTH_SETTINGS" | jq -r '.microsoftAccountEnabled // false')
                if [ "$AAD_ENABLED" = "true" ]; then
                    AUTH_PROVIDER="Microsoft Entra ID"
                else
                    # Check for other providers
                    FACEBOOK=$(echo "$AUTH_SETTINGS" | jq -r '.facebookEnabled // false')
                    GOOGLE=$(echo "$AUTH_SETTINGS" | jq -r '.googleEnabled // false')
                    TWITTER=$(echo "$AUTH_SETTINGS" | jq -r '.twitterEnabled // false')
                    
                    if [ "$FACEBOOK" = "true" ]; then AUTH_PROVIDER="Facebook"; fi
                    if [ "$GOOGLE" = "true" ]; then AUTH_PROVIDER="${AUTH_PROVIDER:+$AUTH_PROVIDER, }Google"; fi
                    if [ "$TWITTER" = "true" ]; then AUTH_PROVIDER="${AUTH_PROVIDER:+$AUTH_PROVIDER, }Twitter"; fi
                    
                    if [ "$AUTH_PROVIDER" = "" ]; then
                        AUTH_PROVIDER="Other/Custom"
                    fi
                fi
            else
                AUTH_ENABLED="❌ No"
            fi
        fi
        
        # Azure Portal link
        PORTAL_LINK="https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME"
        
        # Get App Service Plan details for pricing/SKU
        echo "  → Fetching App Service Plan details..."
        APP_SERVICE_PLAN_ID=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "appServicePlanId" -o tsv 2>/dev/null)
        SKU_NAME="N/A"
        SKU_TIER="N/A"
        SKU_SIZE="N/A"
        INSTANCE_COUNT="N/A"
        ESTIMATED_COST="N/A"
        
        echo "  → App Service Plan ID: $APP_SERVICE_PLAN_ID"
        
        if [ -n "$APP_SERVICE_PLAN_ID" ] && [ "$APP_SERVICE_PLAN_ID" != "null" ]; then
            PLAN_DETAILS=$(az appservice plan show --ids "$APP_SERVICE_PLAN_ID" 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$PLAN_DETAILS" ]; then
                SKU_NAME=$(echo "$PLAN_DETAILS" | jq -r '.sku.name // "N/A"')
                SKU_TIER=$(echo "$PLAN_DETAILS" | jq -r '.sku.tier // "N/A"')
                SKU_SIZE=$(echo "$PLAN_DETAILS" | jq -r '.sku.size // "N/A"')
                INSTANCE_COUNT=$(echo "$PLAN_DETAILS" | jq -r '.sku.capacity // "N/A"')
                
                echo "  → SKU: $SKU_TIER ($SKU_NAME), Instances: $INSTANCE_COUNT"
                
                # Estimate monthly cost based on SKU (European pricing - West Europe region)
                # Prices are approximate and may vary by specific region
                case "$SKU_TIER" in
                    "Free")
                        ESTIMATED_COST="€0/month (Free tier)"
                        ;;
                    "Shared")
                        ESTIMATED_COST="~€8.86/month"
                        ;;
                    "Basic")
                        case "$SKU_SIZE" in
                            "B1") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 13.50" | bc)
                                ESTIMATED_COST="~€13.50/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "B2") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 27.00" | bc)
                                ESTIMATED_COST="~€27.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "B3") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 54.00" | bc)
                                ESTIMATED_COST="~€54.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            *) ESTIMATED_COST="~€13-€54/month per instance" ;;
                        esac
                        ;;
                    "Standard")
                        case "$SKU_SIZE" in
                            "S1") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 67.00" | bc)
                                ESTIMATED_COST="~€67.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "S2") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 134.00" | bc)
                                ESTIMATED_COST="~€134.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "S3") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 268.00" | bc)
                                ESTIMATED_COST="~€268.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            *) ESTIMATED_COST="~€67-€268/month per instance" ;;
                        esac
                        ;;
                    "Premium"|"PremiumV2")
                        case "$SKU_SIZE" in
                            "P1"|"P1v2") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 151.00" | bc)
                                ESTIMATED_COST="~€151.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P2"|"P2v2") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 302.00" | bc)
                                ESTIMATED_COST="~€302.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P3"|"P3v2") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 604.00" | bc)
                                ESTIMATED_COST="~€604.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            *) ESTIMATED_COST="~€151-€604/month per instance" ;;
                        esac
                        ;;
                    "PremiumV3")
                        case "$SKU_SIZE" in
                            "P0v3") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 88.00" | bc)
                                ESTIMATED_COST="~€88.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P1v3") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 176.00" | bc)
                                ESTIMATED_COST="~€176.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P1mv3")
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 176.00" | bc)
                                ESTIMATED_COST="~€176.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P2v3") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 352.00" | bc)
                                ESTIMATED_COST="~€352.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P2mv3")
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 352.00" | bc)
                                ESTIMATED_COST="~€352.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P3v3") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 704.00" | bc)
                                ESTIMATED_COST="~€704.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P3mv3")
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 704.00" | bc)
                                ESTIMATED_COST="~€704.00/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            *) ESTIMATED_COST="~€88-€704/month per instance" ;;
                        esac
                        ;;
                    "PremiumV4")
                        case "$SKU_SIZE" in
                            "P0v4") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 92.76" | bc)
                                ESTIMATED_COST="~€92.76/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P1v4") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 185.52" | bc)
                                ESTIMATED_COST="~€185.52/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P1mv4")
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 218.94" | bc)
                                ESTIMATED_COST="~€218.94/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P2v4") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 371.04" | bc)
                                ESTIMATED_COST="~€371.04/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P2mv4")
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 437.08" | bc)
                                ESTIMATED_COST="~€437.08/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P3v4") 
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 741.28" | bc)
                                ESTIMATED_COST="~€741.28/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            "P3mv4")
                                MONTHLY_COST=$(echo "scale=2; $INSTANCE_COUNT * 874.16" | bc)
                                ESTIMATED_COST="~€874.16/month × $INSTANCE_COUNT instance(s) = ~€${MONTHLY_COST}/month"
                                ;;
                            *) ESTIMATED_COST="~€93-€875/month per instance" ;;
                        esac
                        ;;
                    "Dynamic")
                        ESTIMATED_COST="Consumption-based (Pay per execution)"
                        ;;
                    "ElasticPremium")
                        ESTIMATED_COST="~€148-€592/month per instance (Elastic Premium)"
                        ;;
                    *)
                        ESTIMATED_COST="Custom tier - check Azure Portal"
                        ;;
                esac
            fi
        fi
        
        # Write to CSV (escape commas in fields and remove emoji)
        CSV_AUTH_ENABLED=$(echo "$AUTH_ENABLED" | sed 's/✅ //' | sed 's/❌ //')
        CSV_ESTIMATED_COST=$(echo "$ESTIMATED_COST" | sed 's/~//g')
        echo "\"$APP_NAME\",\"$APP_TYPE\",\"$RESOURCE_GROUP\",\"$LOCATION\",\"$SKU_TIER\",\"$SKU_NAME\",\"$INSTANCE_COUNT\",\"$CSV_ESTIMATED_COST\",\"$CSV_AUTH_ENABLED\",\"$AUTH_PROVIDER\",\"$PORTAL_LINK\"" >> "$CSV_FILE"
        
        # Write to markdown
        {
            echo "## $COUNTER. $APP_NAME"
            echo ""
            echo "- **Type:** $APP_TYPE"
            echo "- **Resource Group:** $RESOURCE_GROUP"
            echo "- **Location:** $LOCATION"
            echo "- **SKU/Pricing Tier:** $SKU_TIER ($SKU_NAME)"
            echo "- **Instance Count:** $INSTANCE_COUNT"
            echo "- **Estimated Cost:** $ESTIMATED_COST"
            echo "- **Microsoft Entra ID Auth:** $AUTH_ENABLED"
            if [ "$AUTH_ENABLED" = "✅ Yes" ]; then
                echo "- **Auth Provider(s):** $AUTH_PROVIDER"
            fi
            echo "- **Portal Link:** [Open in Azure Portal]($PORTAL_LINK)"
            echo ""
            echo "---"
            echo ""
        } >> "$OUTPUT_FILE"
        
        COUNTER=$((COUNTER + 1))
    done
fi

echo "✅ Report generated: $OUTPUT_FILE"
echo "✅ CSV file generated: $CSV_FILE"
echo ""
echo "💡 Note: Cost estimates are approximate based on European (West Europe) pricing."
echo "   Actual costs may vary based on specific region, promotions, and usage patterns."
echo "   For Functions on Consumption plan, costs depend on executions and GB-s."
