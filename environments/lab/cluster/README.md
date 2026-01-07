# The Variant LAB Cluster

## First things first: Naming conventions for Azure Resources in this project

We strive to use the  Cloud Adoption Framework / Azure Resource Namer for naming conventions. 
An online version of this tool is at the time of writing available here:
https://flcdrg.github.io/azure-resource-namer/
If you want to create any new Azure Resource, please generate a name 

## Rudimentary guide to use this folder for managing this Terraformed AKS (Azure Kubernetes Service) Cluster

1. Make sure you have a Terraform Cloud account and homebrew installed
2. If using VSCode, install the "Hashicorp Terraform" extension, and have the extension format any .tf files on save.
Add the following to user settings (settings.json, CMD+SHIFT+P => Preferences: Open User Settings) to achieve this:
```
 "[terraform]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.tabSize": 2
    },
    "[terraform-vars]": {
        "editor.formatOnSave": true,
        "editor.tabSize": 2
    }
```
3. Log in to azure (az login). Go escalate yourself to these 2 roles with PIM:
a) [Cloud Application Administrator](https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/MyActions/resourceId//resourceType/tenant/provider/aadroles) 
b) [Owner (Variant Cluster)](https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac)
c) [User Access Administrator (Variant Cluster)](https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac)
  
4. Add the hashicorp tap and install terraform + az-cli
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install az
brew install kubelogin
```
5. Until we have terraform-cloud running: Make sure you have read-rights to read from the shared-kv-variant keyvault.
 
6. Log in to terraform and azure on the Variant tenant: 
```bash
terraform login
az login
``` 
(Choose the Kompetansebygging subscription)

7. Check if the cluster is alive: 
```bash 
terraform plan
``` 
8. Make a change to any .tf file
9. Check to see how it will plan out: 
```bash
terraform plan
``` 
10. If the change looks good, apply it: 
```bash
terraform apply
``` 

Quick Note #1: When you´re done with the cluster, please issue a "terraform destroy" to avoid accumulating large costs over time.
Quick Note #2:
It might take some time to provision an AKS cluster from scratch. That is in part because we also create a new node-pool with VM(s) serving the cluster.
Not unusual to have a 6 minute creation. So be patient when applying an AKS cluster from scratch:
```
azurerm_kubernetes_cluster.default: Still creating... [06m00s elapsed]
```

Quick Note #3: Azure App Registrations. They require Cloud App Administrator role or equivalent, so running this locally (like we´re doing now) requires escalation of privileges to at least this role, to be able to A: Create and B: Destroy (delete all resources) in this workspace. This is due to ArgoCD warranting a separate appreg witrh a client secret. 


## Useful commands for kubectl:
**Create a deployment template**
```bash
kubectl create deployment <deployment-name> --image <image-name>  --dry-run=client -o yaml > file-name.yml
```

**Apply/deploy resources from a yml file**
```bash
kubectl apply -f file-name.yml
```

**Expose a deployment to the public web in Azure k8s (AKS)**
```bash
kubectl expose deploy/<deployment-name> --type=LoadBalancer --port=80 --name=<name-of-service-this-step-creates>
```

