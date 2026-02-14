# Terraform + GitHub Actions on Azure (ACR + AKS “Hello, World!”)

A learning repo that uses **Terraform** and **GitHub Actions** to:

1) create an **Azure Container Registry (ACR)**, and  
2) create an **Azure Kubernetes Service (AKS)** cluster that runs a tiny web app which responds with:

`Hello, World!`

➡️ Jump to: [Quickstart](#quickstart)

## Overview

This repository is organized into two Terraform deployments (ACR first, then AKS), plus a minimal Java web app and Dockerfile.

```

.
├── .github/
│   └── workflows/
│       ├── deploy_acr.yaml
│       └── deploy_aks.yaml
├── terraform/
│   ├── acr/
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── vars/
│   │       └── poc.tfvars
│   └── aks/
│       ├── main.tf
│       ├── providers.tf
│       ├── variables.tf
│       └── vars/
│           └── poc.tfvars
├── Dockerfile
└── HelloWorld.java

````

## Quickstart

1) Configure **GitHub repo variables** and **GitHub repo secrets** (see [Configuration](#configuration)).
2) Run the **ACR workflow**: `.github/workflows/deploy_acr.yaml` (choose `plan -> apply`).
3) Run the **AKS workflow**: `.github/workflows/deploy_aks.yaml` (choose `plan -> apply`).
4) Verify the app responds with `Hello, World!` (see [Verify](#verify)).

> This repo is intentionally **GitHub Actions–only**. It does not document a local Terraform workflow.

## How it works (novice-friendly)

If you’re new to all of this, here’s the “story” end-to-end:

### 1) The app is a tiny web server
- `HelloWorld.java` starts a simple HTTP server on port `8080`.
- When you visit `/`, it returns `Hello, World!`.

### 2) Docker turns the app into an image
- `Dockerfile` compiles the Java file and packages it into a container image.
- An image is like a “frozen bundle” of your app + everything it needs to run.

### 3) ACR is where the image is stored
- **Azure Container Registry (ACR)** is a private place to store container images.
- The AKS workflow builds the image and pushes it to ACR.

### 4) AKS runs the image
- **Azure Kubernetes Service (AKS)** is a managed Kubernetes cluster.
- Terraform creates:
  - the AKS cluster
  - a Kubernetes **Deployment** (runs your container)
  - a Kubernetes **Service** of type **LoadBalancer** (gives you a public IP)

### 5) AKS is allowed to pull from ACR
- By default, AKS can’t pull private images from ACR.
- Terraform adds an Azure **role assignment** (`AcrPull`) so the cluster’s kubelet identity can pull images from your registry.

### 6) GitHub Actions runs the whole process
Both workflows are started manually via the GitHub UI (workflow_dispatch):

- **Deploy ACR Terraform**
  - runs `terraform plan`
  - saves the plan as an artifact
  - requires approval (GitHub Environment) before applying
  - applies the exact plan

- **Deploy AKS Terraform**
  - runs `terraform plan`
  - requires approval before applying
  - builds + pushes the Docker image to ACR
  - applies the exact plan (which deploys the updated image tag to Kubernetes)

### 7) Authentication + state
Two important “plumbing” concepts are handled by the workflows:

- **Authentication (OIDC):** The workflows use GitHub’s OIDC integration to authenticate to Azure (no long-lived Azure password in the repo).
- **Terraform state (remote backend):** Terraform stores state in Azure Storage. The workflows pass the backend configuration at `terraform init` time.

## Architecture

There are two Terraform deployments:

- `terraform/acr` creates the Azure Container Registry
- `terraform/aks` creates AKS and Kubernetes resources, and references ACR by name

Module docs:
- [terraform/acr](terraform/acr/README.md)
- [terraform/aks](terraform/aks/README.md)

## Configuration

### Repo variables (Actions → Variables)
Create these **repo-level variables**:

- `ACR_NAME`  
  The name of the Azure Container Registry. (ACR names must be globally unique.)
- `IMAGE_NAME`  
  The container image repository name (e.g., `helloworld-java`).

These are also exported into Terraform as environment variables (`TF_VAR_acr_name` and `TF_VAR_image_name`) to ensure the workflow build/push matches what Terraform deploys.

### Repo secrets (Actions → Secrets)
You will need secrets for:

**Azure OIDC**
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

**Terraform backend (Azure Storage)**
- `BACKEND_AZURE_RESOURCE_GROUP_NAME`
- `BACKEND_AZURE_STORAGE_ACCOUNT_NAME`
- `BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME`

> This repo assumes the backend storage exists already and is accessible.

### Environments
The workflows currently support a single environment:
- `poc`

Environment-specific Terraform variables live in:
- `terraform/acr/vars/poc.tfvars`
- `terraform/aks/vars/poc.tfvars`

## Deploy

### Step 1: Deploy ACR
Run workflow: **Deploy ACR Terraform** (`.github/workflows/deploy_acr.yaml`)  
Choose:
- action: `plan -> apply`
- environment: `poc`

### Step 2: Deploy AKS + the app
Run workflow: **Deploy AKS Terraform** (`.github/workflows/deploy_aks.yaml`)  
Choose:
- action: `plan -> apply`
- environment: `poc`

This workflow will:
1) build and push the Docker image to ACR tagged with the Git SHA
2) deploy/update the AKS workload to use that image tag

## Verify

After the AKS workflow completes:
1) Find the external IP assigned to the Kubernetes Service (type `LoadBalancer`)
2) Call it in a browser or with curl:

```bash
curl http://<external-ip>/
````

Expected response:

```text
Hello, World!
```

## Destroy

Both workflows also support `destroy`.

* The **ACR destroy** runs a normal `terraform destroy` for the ACR deployment.
* The **AKS destroy** runs a **targeted destroy** for the AKS cluster and Kubernetes resources defined in `terraform/aks`.

> For a learning repo, it’s normal to destroy and recreate often. Just be aware that destroying cloud resources is permanent.

## Notes and constraints

* **ACR naming:** ACR registry names must be globally unique across Azure.
* **Public exposure:** The app is exposed via a Kubernetes Service of type `LoadBalancer`, which creates a public endpoint.
* **Learning setup:** This repo is intentionally minimal and uses a single environment (`poc`).