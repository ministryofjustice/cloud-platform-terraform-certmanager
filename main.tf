
locals {
  cert-manager-version = "v1.2.0"
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
      "cloud-platform.justice.gov.uk/business-unit"                 = "Platforms"
      "cloud-platform.justice.gov.uk/owner"                         = "Cloud Platform: platforms@digital.justice.gov.uk"
      "cloud-platform.justice.gov.uk/source-code"                   = "https://github.com/ministryofjustice/cloud-platform-infrastructure"
      "cloud-platform.justice.gov.uk/can-use-loadbalancer-services" = "true"
      "iam.amazonaws.com/permitted"                                 = var.eks ? "" : aws_iam_role.cert_manager.0.name
      "cloud-platform-out-of-hours-alert"                           = "true"
    }
  }
}

resource "helm_release" "cert_manager" {
  name          = "cert-manager"
  chart         = "cert-manager"
  repository    = "https://charts.jetstack.io"
  namespace     = kubernetes_namespace.cert_manager.id
  version       = local.cert-manager-version
  recreate_pods = true

  values = [templatefile("${path.module}/templates/values.yaml.tpl", {
    certmanager_role    = var.eks ? "" : aws_iam_role.cert_manager.0.name
    eks                 = var.eks
    eks_service_account = module.iam_assumable_role_admin.this_iam_role_arn
  })]

  depends_on = [
    var.dependence_prometheus,
    var.dependence_opa,
  ]

  lifecycle {
    ignore_changes = [keyring]
  }
}

data "template_file" "clusterissuers_staging" {
  template = file("${path.module}/templates/clusterIssuers.yaml.tpl")
  vars = {
    env         = "staging"
    acme_server = "https://acme-staging-v02.api.letsencrypt.org/directory"
    eks         = var.eks
    iam_role    = var.eks ? "" : aws_iam_role.cert_manager.0.arn
  }
}

data "template_file" "clusterissuers_production" {
  template = file("${path.module}/templates/clusterIssuers.yaml.tpl")
  vars = {
    env         = "production"
    acme_server = "https://acme-v02.api.letsencrypt.org/directory"
    eks         = var.eks
    iam_role    = var.eks ? "" : aws_iam_role.cert_manager.0.arn
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
    command = "kubectl -n cert-manager delete ClusterIssuer letsencrypt-staging letsencrypt-production"
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
    alerts = filesha1("${path.module}/resources/monitoring/alerts.yaml")
  }
}

