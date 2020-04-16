
locals {
  cert-manager-version = "v0.14.1"
  crd-path             = "https://github.com/jetstack/cert-manager/releases/download"
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

    resources = ["arn:aws:route53:::hostedzone/${var.hostzone}"]
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
    resources = [aws_iam_role.cert_manager.arn]
  }
}

resource "aws_iam_role_policy" "cert_manager" {
  name   = "route53"
  role   = aws_iam_role.cert_manager.id
  policy = data.aws_iam_policy_document.cert_manager.json
}

resource "null_resource" "cert_manager_crds" {
  provisioner "local-exec" {
    command = "kubectl apply -n cert-manager --validate=false -f ${local.crd-path}/${local.cert-manager-version}/cert-manager.crds.yaml"
  }
  provisioner "local-exec" {
    when = destroy
    # destroying the CRDs also deletes all resources of type "certificate" (not the actual certs, those are in secrets of type "tls")
    command = "exit 0"
  }
  triggers = {
    content = sha1("${local.crd-path}/${local.cert-manager-version}/cert-manager.crds.yaml")
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

data "template_file" "clusterissuers_staging" {
  template = "${file("${path.module}/templates/clusterIssuers.yaml.tpl")}"
  vars = {
    env         = "staging"
    acme_server = "https://acme-staging-v02.api.letsencrypt.org/directory"
    iam_role    = aws_iam_role.cert_manager.arn
  }
}

data "template_file" "clusterissuers_production" {
  template = "${file("${path.module}/templates/clusterIssuers.yaml.tpl")}"
  vars = {
    env         = "production"
    acme_server = "https://acme-v02.api.letsencrypt.org/directory"
    iam_role    = aws_iam_role.cert_manager.arn
  }
}

resource "null_resource" "cert_manager_issuers" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = "kubectl apply -n cert-manager -f -<<EOF\n${data.template_file.clusterissuers_production.rendered}\nEOF"
  }

  provisioner "local-exec" {
    command = "kubectl apply -n cert-manager -f -<<EOF\n${data.template_file.clusterissuers_staging.rendered}\nEOF"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -n cert-manager -f -<<EOF\n${data.template_file.clusterissuers_production.rendered}\nEOF"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -n cert-manager -f -<<EOF\n${data.template_file.clusterissuers_staging.rendered}\nEOF"
  }

  triggers = {
    contents_staging    = sha1(data.template_file.clusterissuers_staging.rendered)
    contents_production = sha1(data.template_file.clusterissuers_production.rendered)
  }
}

resource "null_resource" "cert_manager_monitoring" {
  depends_on = [
    var.dependence_prometheus,
    helm_release.cert_manager,
  ]

  provisioner "local-exec" {
    command = "kubectl apply -n cert-manager -f ${path.module}/resources/monitoring/alerts.yaml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -n cert-manager -f ${path.module}/resources/monitoring/alerts.yaml"
  }

  triggers = {
    alerts         = filesha1("${path.module}/resources/monitoring/alerts.yaml")
  }
}

