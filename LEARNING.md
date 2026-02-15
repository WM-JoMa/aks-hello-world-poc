## Learning plan for AKS + Terraform + GitHub Actions

### Audience and setup assumptions

* You have a GitHub repo and an Azure subscription.
* Deployments happen only through GitHub Actions using Azure OIDC.
* You’re learning by iterating on a working baseline.

---

## Step 1 - Copy the repo and replicate the deployment

### 1.1\) Fork or copy

* Fork the repository or copy it into a new repo you control.

### 1.2\) Create Azure prerequisites

* Existing Azure Resource Group for the learning environment.
* Azure Storage account and blob container for Terraform remote state.
* Azure AD app registration configured for GitHub OIDC with permissions to create ACR and AKS resources.

### 1.3\) Configure GitHub repo variables and secrets

Repo variables

* `ACR_NAME`
* `IMAGE_NAME`

Repo secrets

* `AZURE_CLIENT_ID`
* `AZURE_TENANT_ID`
* `AZURE_SUBSCRIPTION_ID`
* `BACKEND_AZURE_RESOURCE_GROUP_NAME`
* `BACKEND_AZURE_STORAGE_ACCOUNT_NAME`
* `BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME`

Optional

* Create a GitHub Environment named `poc` and require approvals for apply jobs.

### 1.4\) Deploy via GitHub Actions

* Run Deploy ACR workflow with plan then apply.
* Run Deploy AKS workflow with plan then apply.
* Verify the service external IP responds with `Hello, World!`.

### 1.5\) Connect to the AKS cluster

Goal
Confirm you can access the cluster control plane and inspect the resources Terraform created.

What to do

* Use your preferred method to obtain cluster credentials, such as Azure CLI or the Azure Portal.
* Confirm `kubectl` can talk to the cluster.
* List and inspect the Kubernetes objects created by Terraform

  * Namespace
  * Deployment and pods
  * Service and external IP
* View pod logs and confirm the server is listening on the expected port.

Suggested checks

* `kubectl get namespaces` and confirm the app namespace exists.
* `kubectl get deploy -n <namespace>` and confirm the deployment is available.
* `kubectl get pods -n <namespace>` and confirm pods are Running and Ready.
* `kubectl get svc -n <namespace>` and confirm the service is type LoadBalancer with an external IP.
* `kubectl logs -n <namespace> <pod>` and confirm the app started and is listening.

Learning objectives

* Understand the difference between Azure resources and Kubernetes resources.
* Learn how to verify that Terraform created the intended Kubernetes objects.
* Build confidence debugging at the Kubernetes layer without changing the deployment workflow.

---

## Step 2 - Iterate on the deployment and add improvements

You’ll implement these improvements in small PRs, one theme at a time, with a workflow run after each PR to confirm behavior.

### 2.1\) Add Terraform outputs for ACR and AKS

Work items

* Add `outputs.tf` in `terraform/acr` and `terraform/aks`.
* Outputs for ACR might include registry name and login server.
* Outputs for AKS might include cluster name, namespace, service name, and service external endpoint once available.

Learning objectives

* Learn how outputs help users and downstream tooling.
* Learn the difference between stable outputs and computed values.

Verification

* Workflows show outputs in logs.
* Outputs are correct and useful for verify steps.

### 2.2\) Tighten provider version pinning

Work items

* In both modules, pin provider versions to a narrower compatible range.
* Document why pinning matters and when to upgrade.

Learning objectives

* Understand why provider upgrades can change behavior.
* Learn controlled upgrade practices.

Verification

* `terraform init` uses the intended versions.
* Plans remain stable across reruns.

### 2.3\) Add a formatting check job in GitHub Actions

Work items

* Add a job that runs on pull requests and on manual dispatch.
* Run `terraform fmt -check -recursive`.
* Optionally include `terraform validate` as a separate step.

Learning objectives

* Learn basic CI gates for infrastructure code.
* Learn how to structure multi job workflows.

Verification

* Formatting failures block merges or show clear job failures.
* Formatting passes when code is formatted.

### 2.4\) Add a job summary for AKS outputs

Work items

* After apply in the AKS workflow, run `terraform output` in the AKS working directory.
* Append key outputs to `$GITHUB_STEP_SUMMARY`.

Learning objectives

* Learn to surface useful artifacts to operators.
* Learn how summaries improve usability.

Verification

* The Actions run summary shows the outputs clearly.

### 2.5\) Make the app port configurable

Work items

* Add Terraform variables for container port and service port.
* Ensure the Deployment container port, probes, and Service target port are driven by variables.
* Pass the port into the container via environment variable `PORT` so the Java app matches.
* Update the Dockerfile only if needed, but keep the runtime configuration in Kubernetes.

Learning objectives

* Learn how configuration flows from Terraform to Kubernetes to the container.
* Understand difference between container port and service port.

Verification

* Deploy with a non default port and still get `Hello, World!`.
* Probes succeed.

### 2.6\) Add resource requests and limits

Work items

* Add CPU and memory requests and limits to the Kubernetes Deployment.
* Keep values conservative for a learning cluster.
* Optionally make them variables with defaults.

Learning objectives

* Learn basic Kubernetes scheduling and stability practices.
* Learn why resource settings matter for cost and reliability.

Verification

* Pod schedules successfully.
* Deployment remains healthy.
