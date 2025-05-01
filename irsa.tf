
# IAM Role for ServiceAccounts: This is for EKS

module "iam_assumable_role_admin" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.55.0"
  create_role                   = true
  role_name                     = "cert-manager.${var.cluster_domain_name}"
  provider_url                  = var.eks_cluster_oidc_issuer_url
  role_policy_arns              = [length(aws_iam_policy.cert_manager) >= 1 ? aws_iam_policy.cert_manager.arn : ""]
  oidc_fully_qualified_subjects = ["system:serviceaccount:cert-manager:cert-manager"]
}

resource "aws_iam_policy" "cert_manager" {

  name_prefix = "cert_manager"
  description = "EKS cluster-autoscaler policy for cluster ${var.cluster_domain_name}"
  policy      = data.aws_iam_policy_document.cert_manager_irsa.json
}

data "aws_iam_policy_document" "cert_manager_irsa" {
  statement {
    actions = ["route53:ChangeResourceRecordSets"]

    resources = var.hostzone
  }

  statement {
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}
