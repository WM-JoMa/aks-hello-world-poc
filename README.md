# AKS + Terraform + GitHub Actions Learning Repository

A learning repo that uses **Terraform** and **GitHub Actions** to:

1) create an **Azure Container Registry (ACR)**, and  
2) create an **Azure Kubernetes Service (AKS)** cluster that runs a tiny web app which responds with:

`Hello, World!`

➡️ Jump to: [How it works](#how-it-works)

## Table of contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Architecture](#architecture)
- [Set up the GitHub repo](#set-up-the-github-repo)
- [Configuration](#configuration)
- [Deploy](#deploy)
- [Verify](#verify)
- [Destroy](#destroy)
- [How it works](#how-it-works)
- [Local workflow (optional)](#local-workflow-optional)
- [Notes and constraints](#notes-and-constraints)

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
```
## Prerequisites

You’ll need:

- **An Azure subscription**
- **An existing Azure Resource Group**
  - Terraform looks it up; it does not create it.
- **An Azure Storage account + blob container** for Terraform remote state
- **Azure AD app registration / federated credentials for GitHub OIDC**
  - Represented in GitHub as `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`
- **A public (or Enterprise) GitHub repository** with Actions enabled

> This repo is a learning exercise and keeps infrastructure minimal and explicit.

## Quickstart

1) Create a new fork of this repository as your starting point.
2) Set up GitHub repo **variables** and **secrets**: see [Configuration](#configuration).  
3) Deploy ACR: see [Deploy](#deploy).  
4) Deploy AKS + the app: see [Deploy](#deploy).  
5) Confirm the response: see [Verify](#verify).

## Architecture

There are two Terraform deployments:

- `terraform/acr` creates the Azure Container Registry
- `terraform/aks` creates AKS and Kubernetes resources, and references ACR by name

Module docs:
- [terraform/acr](terraform/acr/README.md)
- [terraform/aks](terraform/aks/README.md)

## Set up the GitHub repo

At a high level:
1) Create a GitHub repository and push this code.
2) Configure repo **variables** and **secrets** (below).
3) Create a GitHub **Environment** named `poc` (optional but recommended) and require approval for deploy jobs if desired.
4) Run the workflows.

### Optional: Require manual approval before apply
Both workflows use `environment: name: poc` on the apply job. If you create a GitHub Environment named `poc`, you can configure:
- required reviewers (manual approval gates)
- environment secrets/vars (not used here, but supported)

## Configuration

### Azure resources assumed to exist
This repo assumes the following already exist in your Azure subscription:
- An Azure **Resource Group** (Terraform looks it up; it does not create it)
- An Azure Storage **account + container** for Terraform remote state
- An Azure AD application / federated credentials for **GitHub OIDC** (represented by the `AZURE_*` secrets)

### Repo variables (Actions → Variables)
Create these **repo-level variables**:

- `ACR_NAME`  
  The name of the Azure Container Registry. (ACR names must be globally unique.)
- `IMAGE_NAME`  
  The container image repository name (e.g., `helloworld-java`).

These are exported into Terraform as environment variables (`TF_VAR_acr_name` and `TF_VAR_image_name`) to ensure the workflow build/push matches what Terraform deploys.

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

## Deploy

> Order matters: deploy **ACR first**, then **AKS**.

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
1) Find the external IP assigned to the Kubernetes Service (type `LoadBalancer`) using your preferred method (Azure Portal is fine).
2) Call it with curl:

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
* The **AKS destroy** is **targeted** to the AKS cluster, role assignment, and the Kubernetes resources created by this module. This helps avoid accidentally destroying unrelated resources that may exist in the same Resource Group.

> For a learning repo, it’s normal to destroy and recreate often. Just be aware that destroying cloud resources is permanent.

## How it works

### 1) The app is a tiny web server
- `HelloWorld.java` starts a simple HTTP server on port `8080`.
- When you visit `/`, it returns `Hello, World!`. It's important to note that this won't be visible in a browser because it isn't valid HTML.

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
You start both workflows manually from the GitHub UI. Each workflow runs Terraform using:
- **OIDC authentication** to Azure (no long-lived Azure password in the repo)
- an **Azure Storage remote backend** for Terraform state
- a **plan → apply** flow (with optional manual approval via GitHub Environments)

### 7) Why ACR and AKS are separate workflows

ACR and AKS are deployed in **two separate Terraform configurations** and **two separate GitHub Actions workflows** on purpose:

- **They are independent layers.**  
  ACR is foundational infrastructure (a place to store images). AKS is the runtime environment (a cluster that pulls and runs images). Keeping them separate makes the dependency clear: **AKS needs ACR to exist first**, but ACR does not depend on AKS.

- **Different change frequency.**  
  You typically create ACR once and rarely change it. You may update the AKS workload often (new image tags, new app settings, Kubernetes changes). Separating workflows lets you redeploy AKS without touching ACR.

- **Cleaner, smaller Terraform state.**  
  Each Terraform deployment has its own remote state file:
  - ACR uses `acr_<environment>.tfstate`
  - AKS uses `aks_<environment>.tfstate`  
  Smaller, focused state files are easier to understand and reduce the “blast radius” of changes.

- **Safer applies and destroys.**  
  Having separate workflows reduces the chance that an AKS change accidentally modifies or destroys ACR (or vice versa). It also allows different destroy behavior (for example, the AKS workflow uses a targeted destroy).

- **Build/push fits naturally with the AKS deployment.**  
  The AKS workflow builds and pushes the Docker image to ACR and then deploys Kubernetes resources that reference that image tag. Keeping build/push next to the AKS apply makes the delivery flow easy to follow.

In short: **ACR is the image store; AKS is the image runner**—separating workflows keeps the learning repo easier to reason about and safer to operate.

➡️ Jump to: [Quickstart](#quickstart)

## Local workflow (optional)

If you want to run Terraform locally (instead of GitHub Actions), the key is to mirror what the workflows do:

* Use Azure OIDC or another supported `azurerm` auth method
* Configure the AzureRM backend at `terraform init` time
* Provide required variables (tfvars + `TF_VAR_*`)

> The GitHub Actions workflows are the “source of truth” for how this repo is intended to run. Local steps below are provided for convenience.

### Local: ACR

From repo root:

```bash
cd terraform/acr

# Backend config (replace placeholders)
terraform init -upgrade \
  -backend-config="resource_group_name=<BACKEND_RG>" \
  -backend-config="storage_account_name=<BACKEND_STORAGE_ACCOUNT>" \
  -backend-config="container_name=<BACKEND_CONTAINER>" \
  -backend-config="key=acr_poc.tfstate"

# Supply ACR name the same way the workflow does
export TF_VAR_acr_name="<ACR_NAME>"

terraform plan -var-file="vars/poc.tfvars"
terraform apply -var-file="vars/poc.tfvars"
```

### Local: AKS

From repo root:

```bash
cd terraform/aks

terraform init -upgrade \
  -backend-config="resource_group_name=<BACKEND_RG>" \
  -backend-config="storage_account_name=<BACKEND_STORAGE_ACCOUNT>" \
  -backend-config="container_name=<BACKEND_CONTAINER>" \
  -backend-config="key=aks_poc.tfstate"

# Supply shared values the same way the workflow does
export TF_VAR_acr_name="<ACR_NAME>"
export TF_VAR_image_name="<IMAGE_NAME>"

# Use any tag you pushed (the workflow uses the Git SHA)
terraform plan -var-file="vars/poc.tfvars" -var="image_tag=<TAG>"
terraform apply -var-file="vars/poc.tfvars" -var="image_tag=<TAG>"
```

> Local Docker build/push is intentionally not documented here; the GitHub Actions AKS workflow performs build/push automatically during apply.

## Notes and constraints

* **ACR naming:** ACR registry names must be globally unique across Azure.
* **Public exposure:** The app is exposed via a Kubernetes Service of type `LoadBalancer`, which creates a public endpoint.
* **Learning setup:** This repo is intentionally minimal and uses a single environment (`poc`).
