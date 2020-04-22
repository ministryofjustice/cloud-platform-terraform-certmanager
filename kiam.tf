

data "aws_iam_policy_document" "cert_manager_assume" {
  count = var.eks ? 0 : 1

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.iam_role_nodes]
    }
  }
}

resource "aws_iam_role" "cert_manager" {
  count = var.eks ? 0 : 1

  name               = "cert-manager.${var.cluster_domain_name}"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume.0.json
}

data "aws_iam_policy_document" "cert_manager" {
  count = var.eks ? 0 : 1

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

  statement {
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.cert_manager.0.arn]
  }
}

resource "aws_iam_role_policy" "cert_manager" {
  count = var.eks ? 0 : 1

  name   = "route53"
  role   = aws_iam_role.cert_manager.0.id
  policy = data.aws_iam_policy_document.cert_manager.0.json
}
