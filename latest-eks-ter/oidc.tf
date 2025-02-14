# data "aws_eks_cluster" "eks" {
#   name = module.eks.cluster_name
#   depends_on = [module.eks]  # Ensures EKS is created first
# }

# data "tls_certificate" "eks" {
#   url = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
#   depends_on = [module.eks]  # Ensures OIDC URL is available
# }

# resource "aws_iam_openid_connect_provider" "eks" {
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
#   url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer

#   depends_on = [module.eks]  # Ensures EKS is ready before OIDC creation
# }

# output "eks_oidc_url" {
#   value = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
# }