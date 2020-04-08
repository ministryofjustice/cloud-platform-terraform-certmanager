
locals {
  cert-manager-version = "v0.8.1"
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"

    labels = {
      "name"                                           = "cert-manager"
      "component"                                      = "cert-manager"
      "cloud-platform.justice.gov.uk/environment-name" = "production"
      "cloud-platform.justice.gov.uk/is-production"    = "true"
      "certmanager.k8s.io/disable-validation"          = "true"
    }

    annotations = {
      "cloud-platform.justice.gov.uk/application"                   = "cert-manager"
      "cloud-platform.justice.gov.uk/business-unit"                 = "cloud-platform"
      "cloud-platform.justice.gov.uk/owner"                         = "Cloud Platform: platforms@digital.justice.gov.uk"
      "cloud-platform.justice.gov.uk/source-code"                   = "https://github.com/ministryofjustice/cloud-platform-infrastructure"
      "cloud-platform.justice.gov.uk/can-use-loadbalancer-services" = "true"
      "iam.amazonaws.com/permitted"                                 = aws_iam_role.cert_manager.name
    }
  }
}

data "aws_iam_policy_document" "cert_manager_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.iam_role_nodes]
    }
  }
}

resource "aws_iam_role" "cert_manager" {
  name               = "cert-manager.${var.cluster_domain_name}"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume.json
}

data "aws_iam_policy_document" "cert_manager" {
  statement {
    actions = ["route53:ChangeResourceRecordSets"]

    resources = [ "arn:aws:route53:::hostedzone/${var.hostzone}" ]
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

resource "aws_iam_role_policy" "cert_manager" {
  name   = "route53"
  role   = aws_iam_role.cert_manager.id
  policy = data.aws_iam_policy_document.cert_manager.json
}

data "http" "cert_manager_crds" {
  url = "https://raw.githubusercontent.com/jetstack/cert-manager/${local.cert-manager-version}/deploy/manifests/00-crds.yaml"
}

resource "null_resource" "cert_manager_crds" {
  provisioner "local-exec" {
    command = <<EOS
kubectl apply -n cert-manager -f - <<EOF
${data.http.cert_manager_crds.body}
EOF
EOS

  }

  provisioner "local-exec" {
    when = destroy

    # destroying the CRDs also deletes all resources of type "certificate" (not the actual certs, those are in secrets of type "tls")
    command = "exit 0"
  }

  triggers = {
    contents_crds = sha1(data.http.cert_manager_crds.body)
  }
}

data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

resource "helm_release" "cert_manager" {
  name          = "cert-manager"
  chart         = "jetstack/cert-manager"
  repository    = data.helm_repository.jetstack.metadata[0].name
  namespace     = kubernetes_namespace.cert_manager.id
  version       = local.cert-manager-version
  recreate_pods = true

  values = [templatefile("${path.module}/templates/values.yaml.tpl", {
    certmanager_role = aws_iam_role.cert_manager.name
  })]

  depends_on = [
    var.dependence_deploy,
    null_resource.cert_manager_crds,
    var.dependence_opa,
  ]

  lifecycle {
    ignore_changes = [keyring]
  }
}

resource "null_resource" "cert_manager_issuers" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = "kubectl apply -n cert-manager -f ${path.module}/resources/letsencrypt-production.yaml"
  }

  provisioner "local-exec" {
    command = "kubectl apply -n cert-manager -f ${path.module}/resources/letsencrypt-staging.yaml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -n cert-manager -f ${path.module}/resources/letsencrypt-production.yaml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -n cert-manager -f ${path.module}/resources/letsencrypt-staging.yaml"
  }

  triggers = {
    contents_production = filesha1(
      "${path.module}/resources/letsencrypt-production.yaml",
    )
    contents_staging = filesha1(
      "${path.module}/resources/letsencrypt-staging.yaml",
    )
  }
}

resource "null_resource" "cert_manager_monitoring" {
  depends_on = [
    var.dependence_prometheus,
    helm_release.cert_manager,
  ]

  provisioner "local-exec" {
    command = "kubectl apply -n cert-manager -f ${path.module}/resources/monitoring/"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -n cert-manager -f ${path.module}/resources/monitoring/"
  }

  triggers = {
    servicemonitor = filesha1("${path.module}/resources/monitoring/servicemonitor.yaml")
    alerts         = filesha1("${path.module}/resources/monitoring/alerts.yaml")
  }
}

