## z2j-aws

A take on [Zero-to-JupyterHub with Kubernetes](https://zero-to-jupyterhub.readthedocs.io/en/latest/)
using a very specific tech stack, namely:

- [Terraform](https://www.terraform.io/) for AWS infrastructure config management
- [AWS Elastic Kubernetes Service](https://aws.amazon.com/eks/) (EKS) via the
  [howdio EKS Terraform module](https://registry.terraform.io/modules/howdio/eks/aws/0.6.0)
- [AWS Elastic Container Registry](https://aws.amazon.com/ecr/) (ECR) for storing custom JupyterHub
  and user images
- [Helm](https://helm.sh/) and [Helmfile](https://github.com/roboll/helmfile) for deploying
  applications to Kubernetes including
  [external-dns](https://github.com/kubernetes-incubator/external-dns),
  [nginx-ingress](https://github.com/kubernetes/ingress-nginx),
  [jetstack/cert-manager](https://github.com/jetstack/cert-manager), and
  [jupyterhub](https://github.com/jupyterhub/helm-chart)
- [Cloudflare](https://cloudflare.com) for DNS
- [Let's Encrypt](https://letsencrypt.org/) for TLS certificates
- [Homebrew](https://brew.sh/) for installing client tools on macOS
- [Make](https://www.gnu.org/software/make/) for simplifying local commands

## Before You Begin

Make sure the tech stack above and all the complexity that comes with it are a good fit for your use
case before continuing. Here are some alternatives:

- If you only need a Jupyter Notebook server for yourself, you do not need to set up JupyterHub. You
  should instead follow the instructions to
  [install](https://jupyter.readthedocs.io/en/latest/install.html) and
  [run](https://jupyter.readthedocs.io/en/latest/running.html) a standalone Jupyter Notebook server.
- If you need to run Jupyter Notebook servers for a small group of people and have no interest in
  learning about Kubernetes, you will be better off following the guide for
  [The Littlest JupyterHub](https://the-littlest-jupyterhub.readthedocs.io/en/latest/).
- If you intend to use a Kubernetes provider other than AWS, you should follow the instructions in
  the full [Zero-to-JupyterHub](https://zero-to-jupyterhub.readthedocs.io/en/latest/) guide.
- If you are familiar with Kubernetes but have never configured JupyterHub on run on k8s before, you
  should follow the instructions in the full
  [Zero-to-JupyterHub](https://zero-to-jupyterhub.readthedocs.io/en/latest/) guide at least once
  before using the highly-opinionated shortcuts enabled by this repository.

## Prerequisites

- macOS
- Homebrew
- A public domain name

## Basic Usage

1. Install tools used throughout the rest of the instructions using `brew`.

   ```shell
   make client-prereqs
   ```

1. Create an
   [AWS IAM access key and secret](https://aws.amazon.com/premiumsupport/knowledge-center/create-access-key/)
   for the account that will be used to provision AWS infrastructure.
1. Configure a profile (e.g., `personal`) in `~/.aws/credentials` containing the IAM credentials and
   desired region for your AWS infrastructure.

   ```
   [personal]
   aws_access_key_id=YOUR_IAM_KEY_ID
   aws_secret_access_key=YOUR_IAM_KEY_SECRET
   region=us-east-1
   ```

1. Configure Elastic Kubernetes Service (EKS) and Elastic Container Registry (ECR) instances on AWS
   using Terraform. **Fair warning: AWS will start charging you after you run this command.**

   ```shell
   export AWS_PROFILE=personal
   make k8s-cluster
   ```

1. Sign up for a (free) [CloudFlare](https://cloudflare.com) account if you don't already have one.
1. Add a site to your Cloudflare account matching your domain name (e.g., `parente.dev`).
1. Login to your domain name registrar to configure your domain name to use the CloudFlare
   nameservers (currently, `alec.ns.cloudflare.com` and `alice.ns.cloudflare.com`).
1. Get your CloudFlare API token from My Profile &rarr; API Tokens &rarr; Global API Key in the
   CloudFlare web app.
1. Apply configurations to Kubernetes for Helm tiller, nginx ingress, Let's Encrypt cert issuer, and
   CloudFlare DNS.

   ```shell
   export FQDN=parente.dev
   export CLOUDFLARE_API_KEY=YOUR_CLOUDFLARE_API_KEY
   export CLOUDFLARE_EMAIL=parente@gmail.com
   make k8s-services
   ```

1. Deploy JupyterHub configured to use the `jupyter/minimal-notebook` and
   [FirstUseAuthenticator](https://github.com/jupyterhub/firstuseauthenticator).

   ```shell
   make jupyterhub
   ```

1. Visit `https://YOUR_DOMAIN` in your browser.
1. Login with username `admin` and a strong password of your choosing.
1. Click File &rarr; Hub Control Panel &rarr; Admin &rarr; Add Users to populate a whitelist of
   users allowed to login.

## Customization / How do I ...

### See what's configured in Kubernetes

```shell
make show
```

### Use a different JupyterHub Docker image tag

See https://jupyterhub.github.io/helm-chart/ for available versions and
https://github.com/jupyterhub/zero-to-jupyterhub-k8s/tree/master/images/hub for the contents of each
image. Substitute the version you want into the command below.

```shell
make jupyterhub HUB_IMAGE_TAG=0.8.2
```

### Use a different Docker image as my user environment

Choose any of the images maintained at or derived from https://github.com/jupyter/docker-stacks.
Produce one of your own using https://github.com/jupyterhub/repo2docker. Then substitute the image
name and tag in the command below.

```
make jupyterhub USER_IMAGE=jupyter/datascience-notebook USER_IMAGE_TAG=2ce7c06a61a1
```

### Build private, custom JupyterHub and user Docker images

1. Modify the `Dockerfile.hub` and `Dockerfile.user` files in this repository so that they define
   the Docker images you want to use.
2. Run the following commands to build the images and push them to the AWS ECR instances you
   provisioned during setup. Specify whatever tag / version number you want to assign to the images
   (default: `latest`).

   ```shell
   make hub-image HUB_IMAGE_TAG=1
   make user-image USER_IMAGE_TAG=1
   ```

3. Run the following command to deploy JupyterHub with your custom images:

   ```shell
   make jupyterhub-custom HUB_IMAGE_TAG=1 USER_IMAGE_TAG=1
   ```

### Use a different method of authentication

Modify the `auth` section

### Use a different DNS, Kubernetes, TLS, etc. provider

Refer to the
[Zero to JupyterHub with Kubernetes](https://zero-to-jupyterhub.readthedocs.io/en/latest/)
documentation and share your own take on the general instructions in your own GitHub project.

### Run these commands on a different operating system

Use the approprate package manager for your platform to install all of the tools instead by
`make client-prereqs`. If `make` is not any option for you, run the commands specified in the
`Makefile` directly.

### Run kubectl commands

```shell
cd z2jh-aws
export KUBECONFIG=./output/jupyterhub/kubeconfig-jupyterhub
kubectl get pods
```

### Tear everything down

```shell
make destroy
```
