# The infrastructure-as-code repository
Terraform configuration and deployment manifests supporting our Variant Platform azure resources.

## Repository structure

```
infrastructure-as-code/
├── deployments/          # Kubernetes manifests and ArgoCD applications
│   ├── dev/             # Development environment workloads
│   │   ├── argocd-apps/    # ArgoCD Application definitions
│   │   └── workloads/      # Helm charts and Kustomize configs
│   ├── prod/            # Production environment workloads
│   │   ├── argocd-apps/
│   │   └── workloads/
│   └── lab/             # Lab/experimental environment workloads
│       ├── argocd-apps/
│       └── workloads/
├── environments/         # Terraform configurations for Azure infrastructure
│   ├── lab/             # Lab cluster infrastructure
│   │   └── cluster/        # AKS, networking, ArgoCD, ingress
│   ├── prod/            # Production cluster infrastructure
│   │   └── cluster/        # AKS, networking, ArgoCD, ingress
│   └── shared/          # Shared Azure resources
│       └── cluster/        # ACR, Key Vault, resource groups
|── .github/             # Reusable GitHub / actions, for app code repositories to reuse
└── utilities/           # Various useful helper utilities when dealing with Azure. Dont be afraid to add your own utilities here!
```

**`deployments/`** - Contains all Kubernetes deployment manifests organized by environment. This is where your application configurations live and what ArgoCD watches for changes.

**`.github/`** - Contains reusable GitHub Actions workflows (in `.github/workflows/`) that can be referenced by other code repositories. These shared workflows provide standardized build and deploy automation for all Variant Platform projects. To use them, code repositories can call these workflows via `uses:` in their own workflow YAML, enabling consistent CI/CD across services  ( [sample consumer usage](./.github/workflows/build-and-deploy-consumer.yaml.sample) ).

**`environments/`** - Contains Terraform code that provisions and manages Azure infrastructure (AKS clusters, networking, ArgoCD installation, etc.). This is the foundation that supports Variants Platform deployments.

## Deploying new applications with ArgoCD to /deployments

This repository uses ArgoCD's **App-of-Apps pattern** to provide a seamless GitOps deployment experience. 

### THE TL;DR: Deploy Your Application (Gold Standard)

For those of you who wants an easy way out (maybe you even TL;DR´d already), here´s a gold standard setup:
You need:

- Some [Code](https://github.com/varianter/k8s-gold-standard-deployment)
- A [Dockerfile](https://github.com/varianter/k8s-gold-standard-deployment/blob/main/Dockerfile) 
- A reusable [GitHub Action](https://github.com/varianter/k8s-gold-standard-deployment/blob/main/.github/workflows/build-and-deploy.yaml)
- A workload [deployment](https://github.com/varianter/infrastructure-as-code/tree/main/deployments/dev/workloads/goldstandard) - feel free to copy/paste and replace the goldstandard workload
- An [ArgoCD App](https://github.com/varianter/infrastructure-as-code/blob/main/deployments/dev/argocd-apps/goldstandard.yaml) - feel free to copy/paste and replace the goldstandard argo app

You can create a PR for the workload and argocd app by running this GitHub Actions job here:
[Add new workload PR (GitHub Actions)](https://github.com/varianter/infrastructure-as-code/actions/workflows/add-new-workload.yaml)

Or do it manually by running  the utilities/add-new-workload.sh script like so:
```
# Be in root of the repo
./utilities/add-new-workload.sh -appname myappname -subdomain MYAPP -environment dev
```


And you will have your MYAPP.dev.variant.dev running in no time!



### WALL OF TEXT: Deploy Your Application

To deploy your application, you need two things:

1. **An ArgoCD Application manifest** in `deployments/<env>/argocd-apps/`
2. **Your deployment manifests** (Helm chart or Kustomize) in `deployments/<env>/workloads/`

#### Step 1: Create Your ArgoCD Application

Create a YAML file in the appropriate environment's `argocd-apps` directory:

```yaml
# deployments/dev/argocd-apps/myapp.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/varianter/infrastructure-as-code
    targetRevision: HEAD
    path: deployments/dev/workloads/myapp-dev
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### Step 2: Create Your Deployment Manifests

Create your Helm chart or Kustomize configuration in the corresponding workloads directory:

**Option A: Helm Chart**
```
deployments/dev/workloads/myapp-dev/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── ingress.yaml
```

**Option B: Kustomize**
```
deployments/dev/workloads/myapp-dev/
├── kustomization.yaml
├── deployment.yaml
└── service.yaml
```

#### Step 3: Commit and Push

That's it! Once you commit and push your changes:

1. The **App-of-Apps** controller detects the new ArgoCD Application in `argocd-apps/`
2. ArgoCD creates your Application and starts monitoring the `workloads/` path
3. Your application is automatically deployed to the cluster
4. ArgoCD continuously syncs your app whenever you update the manifests

### Step 4: Visit the ArgoCD UI to watch your deployment unfold
1. Navigate to the ArgoCD UI: https://argocd.variant.dev/
2. Log in with SSO (Make sure you are a member of the 'Developer' AD group)
3. Filter on the name of your app in the top bar - your app and its state should be visible there


### How It Works

The App-of-Apps pattern works by having a parent ArgoCD Application that watches the `deployments/<env>/argocd-apps/` directory. When you add a new Application manifest there, ArgoCD automatically creates and manages it.

```
┌─────────────────────────────────────────┐
│  App-of-Apps (managed by Terraform)    │
│  Watches: deployments/dev/argocd-apps/ │
└──────────────┬──────────────────────────┘
               │ Discovers
               ▼
┌─────────────────────────────────────────┐
│  Your ArgoCD Application                │
│  (myapp.yaml)                           │
│  Watches: deployments/dev/workloads/    │
└──────────────┬──────────────────────────┘
               │ Deploys
               ▼
┌─────────────────────────────────────────┐
│  Your Kubernetes Resources              │
│  (Deployment, Service, Ingress, etc.)   │
└─────────────────────────────────────────┘
```

### Image Tag Management

You have two options for managing container image tags:

**Option 1: Environment-Specific Tags**
Use tags like `dev`, `prod`, or `staging` in your `values.yaml`:
```yaml
image:
  repository: variantplatformacr.azurecr.io/myapp
  tag: dev
```

**Option 2: Automated Image Tag Updates**
Use a shared GitHub Actions workflow to automatically update the image tag in your deployment manifests when you build new images. This allows you to use specific commit SHAs or semantic versions:
```yaml
image:
  repository: variantplatformacr.azurecr.io/myapp
  tag: abc1234  # Updated automatically by CI/CD
```

The workflow can update the tag in this repository, triggering ArgoCD to deploy the new version automatically.

### Environment Structure

> **Note:** Both DEV and PROD workloads are currently deployed to the **PROD cluster**. They are isolated using Kubernetes namespaces (`dev` and `prod` respectively).

Available environments:
- **`deployments/dev/`** - Development environment
- **`deployments/prod/`** - Production environment
- **`deployments/lab/`** - Lab/experimental environment (see Lab Cluster section below)

### Best Practices

1. **Keep ArgoCD apps separate**: Only put ArgoCD Application manifests in `argocd-apps/`. Keep Helm values, configs, and other files in `workloads/`.

2. **Use automated sync policies**: Enable `prune` and `selfHeal` for true GitOps - your cluster state will always match Git.

3. **Namespace isolation**: Use the `syncOptions: [CreateNamespace=true]` to let ArgoCD create namespaces automatically.

4. **Secrets management**: Use Azure Key Vault with the CSI driver (see existing examples like `dash-dev` for the pattern).

5. **Test in dev first**: Deploy to the `dev` environment and namespace before promoting to `prod`.
