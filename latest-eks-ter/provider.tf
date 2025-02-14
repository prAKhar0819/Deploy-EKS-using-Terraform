# Configure the AWS Provider
provider "aws" {
  region = var.region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

  }
}



data "aws_eks_cluster" "demo" {
  name = var.cluster_name

  depends_on = [module.eks]
}
data "aws_eks_cluster_auth" "demo" {
  name = var.cluster_name

  depends_on = [module.eks]
}


provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.demo.endpoint
    token                  = data.aws_eks_cluster_auth.demo.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.demo.certificate_authority.0.data)
  }
}


# Data source to fetch the OIDC certificate thumbprint dynamically
data "tls_certificate" "demo" {
  url = data.aws_eks_cluster.demo.identity[0].oidc[0].issuer

  depends_on = [module.eks]
}

# IAM OIDC Provider resource, using the dynamically fetched thumbprint
resource "aws_iam_openid_connect_provider" "demo" {
  url             = data.aws_eks_cluster.demo.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.demo.certificates[0].sha1_fingerprint]
}

# installing metrics-server for hpa
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}"
  }
}

# installing keda

resource "helm_release" "keda" {
  name       = "keda"
  namespace  = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"

  create_namespace = true

  set {
    name  = "operator.namespace"
    value = "keda"
  }

  set {
    name  = "installCRDs"
    value = "true"
  }

  
}


# install karpenter

provider "kubernetes" {
  host                   = data.aws_eks_cluster.demo.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.demo.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.demo.token
 # token                  = data.aws_eks_cluster_auth.eks_auth.demo.token
}


resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = "karpenter"
  repository = "https://charts.karpenter.sh/"
  chart      = "karpenter"
  create_namespace = true

  values = [<<EOF
controller:
  env:
    - name: AWS_REGION
      value: "${var.region}"   # Set your AWS region dynamically
EOF
  ]

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "karpenter"
  }

    set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_role.arn
  }

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.demo.name
  }

  set {
    name  = "clusterEndpoint"
    value = data.aws_eks_cluster.demo.endpoint
  }

  set {
    name  = "aws.region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }




}
