#!/bin/bash
# Login to source and destination ACRs. 
# Transfer a list of Container images from source to destination ACR.
# Usage:
#   ./transfer-container-images.sh -s <sourceregistry> -d <destinationregistry> -su <sourceusername> -du <destinationusername>
# Environment Variables:
#   SOURCEPASSWORD: Password for source ACR
#   DESTINATIONPASSWORD: Password for destination ACR
#   IMAGES: Comma-separated list of images to transfer (e.g. "image1:tag1,image2:tag2")

while getopts s:d:su:du: flag
do
    case "${flag}" in
        s) SOURCEREGISTRY=${OPTARG};;
        d) DESTINATIONREGISTRY=${OPTARG};;
        su) SOURCEUSERNAME=${OPTARG};;
        du) DESTINATIONUSERNAME=${OPTARG};;
    esac
done

# make sure SOURCEPASSWORD and DESTINATIONPASSWORD environment variables are set
if [ -z "$SOURCEPASSWORD" ] || [ -z "$DESTINATIONPASSWORD" ]; then
  echo "SOURCEPASSWORD and DESTINATIONPASSWORD environment variables must be set"
  exit 1
fi  

# make sure IMAGES environment variable is set and contains a comma-separated list of images
if [ -z "$IMAGES" ]; then
  echo "IMAGES environment variable must be set and contain a comma-separated list of images"
  exit 1
fi

docker login -u $SOURCEUSERNAME -p $SOURCEPASSWORD $SOURCEREGISTRY.azurecr.io
docker login -u $DESTINATIONUSERNAME -p $DESTINATIONPASSWORD $DESTINATIONREGISTRY.azurecr.io

# List of images to transfer
IFS=',' read -ra images <<< "$IMAGES"

# Transfer each image
for image in "${images[@]}"
do
  docker pull "$SOURCEREGISTRY.azurecr.io/$image"
  docker tag "$SOURCEREGISTRY.azurecr.io/$image" "$DESTINATIONREGISTRY.azurecr.io/$image"
  docker push "$DESTINATIONREGISTRY.azurecr.io/$image"
done