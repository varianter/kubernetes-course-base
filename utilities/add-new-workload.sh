
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -appname)
            WORKLOAD_NAME="$2"
            shift 2
            ;;
        -subdomain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        -environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -auto)
            AUTO_FLAG="-auto"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 -appname WORKLOAD_NAME -subdomain DOMAIN_NAME -environment ENVIRONMENT [-auto]"
            echo "Example: $0 -appname my-new-workload -subdomain my-subdomain -environment dev"
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$WORKLOAD_NAME" ] || [ -z "$DOMAIN_NAME" ] || [ -z "$ENVIRONMENT" ] ; then
    echo "Error: Both -appname, -subdomain, and -environment are required"
    echo "Usage: $0 -appname WORKLOAD_NAME -subdomain DOMAIN_NAME -environment ENVIRONMENT [-auto]"
    echo "Example: $0 -appname my-new-workload -subdomain my-subdomain -environment dev"
    exit 1
fi

# Extrapolate the subdomain. if ENVIRONMENT = dev, full domain will be DOMAIN_NAME.dev.variant.dev
# If ENVIRONMENT = prod, full domain will be DOMAIN_NAME.variant.dev
if [ "$ENVIRONMENT" = "dev" ]; then
  FULL_SUBDOMAIN="$DOMAIN_NAME.dev"
elif [ "$ENVIRONMENT" = "prod" ]; then
  FULL_SUBDOMAIN="$DOMAIN_NAME"
else
  echo "Error: ENVIRONMENT must be either 'dev' or 'prod'"
  exit 1
fi  

# Sanity check for the user. Allow to cancel if it does not look good. Can be bypassed when third argument -auto is provided
echo "You are about to create a new workload with the following parameters:"
echo "Workload name: $WORKLOAD_NAME"
echo "Domain name: $FULL_SUBDOMAIN.variant.dev"
echo "Environment: $ENVIRONMENT"
if [ "$AUTO_FLAG" != "-auto" ]; then
  read -p "Do you want to proceed? (y/n): " choice
  case "$choice" in
    y|Y ) echo "Proceeding...";;
    n|N ) echo "Operation cancelled."; exit 1;;
    * ) echo "Invalid choice. Operation cancelled."; exit 1;;
  esac
fi

#make sure WORKLOAD_NAME is a lower-case kebab-case string
if [[ ! $WORKLOAD_NAME =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Error: WORKLOAD_NAME must be a lower-case kebab-case string (e.g., my-new-workload)"
  exit 1
fi
# make sure the subdomain can be used with VALUE.dev.variant.dev as a valid subdomain
if [[ ! $DOMAIN_NAME =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Error: DOMAIN_NAME must be a lower-case kebab-case string (e.g., my-subdomain)"
  exit 1
fi

# Copy base structure from deployments/shared/workload-boilerplate-helm
TARGET_DIR="./deployments/$ENVIRONMENT/workloads/$WORKLOAD_NAME"
mkdir -p $TARGET_DIR
cp -R ./deployments/shared/workload-boilerplate-helm/* $TARGET_DIR
  for file in $(find $TARGET_DIR -type f); do
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/%WORKLOAD%/$WORKLOAD_NAME/g" "$file"
      sed -i '' "s/%ENVIRONMENT%/$ENVIRONMENT/g" "$file"
      sed -i '' "s/%SUBDOMAIN%/$FULL_SUBDOMAIN/g" "$file"
    else
      sed -i "s/%WORKLOAD%/$WORKLOAD_NAME/g" "$file"
      sed -i "s/%ENVIRONMENT%/$ENVIRONMENT/g" "$file"
      sed -i "s/%SUBDOMAIN%/$FULL_SUBDOMAIN/g" "$file"
    fi
  done
# Replace all of the WORKLOAD_REPLACEME strings with the actual workload name
find $TARGET_DIR -type f -exec sed -i "s/%WORKLOAD%/$WORKLOAD_NAME/g" {} +
find $TARGET_DIR -type f -exec sed -i "s/%ENVIRONMENT%/$ENVIRONMENT/g" {} +
# Replace all of the DOMAINNAME_REPLACEME strings with the actual domain name
find $TARGET_DIR -type f -exec sed -i "s/%SUBDOMAIN%/$FULL_SUBDOMAIN/g" {} +
echo "New workload created at $TARGET_DIR"
echo "Don't forget to customize the values.yaml file!"
# Copy boilerplate argocd app from deployments/shared/argocd-app-boilerplate/$ENVIRONMENT.yaml
ARGOCD_APP_DIR="./deployments/$ENVIRONMENT/argocd-apps"
cp ./deployments/shared/argocd-app-boilerplate/$ENVIRONMENT.yaml "$ARGOCD_APP_DIR/$WORKLOAD_NAME.yaml"
# Replace all of the WORKLOAD_REPLACEME strings with the actual workload name
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/%WORKLOAD%/$WORKLOAD_NAME/g" "$ARGOCD_APP_DIR/$WORKLOAD_NAME.yaml"
else
  sed -i "s/%WORKLOAD%/$WORKLOAD_NAME/g" "$ARGOCD_APP_DIR/$WORKLOAD_NAME.yaml"
fi