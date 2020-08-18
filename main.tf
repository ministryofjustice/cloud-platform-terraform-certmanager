
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
      "iam.amazonaws.com/permitted"                                 = var.eks ? "" : aws_iam_role.cert_manager.0.name
    }
  }
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
  chart         = "cert-manager"
  repository    = data.helm_repository.jetstack.metadata[0].name
  namespace     = kubernetes_namespace.cert_manager.id
  version       = local.cert-manager-version
  recreate_pods = true

  values = [templatefile("${path.module}/templates/values.yaml.tpl", {
    certmanager_role    = var.eks ? "" : aws_iam_role.cert_manager.0.name
    eks                 = var.eks
    eks_service_account = module.iam_assumable_role_admin.this_iam_role_arn
  })]

  depends_on = [
    null_resource.cert_manager_crds,
    var.dependence_prometheus,
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
    eks         = var.eks
    iam_role    = var.eks ? "" : aws_iam_role.cert_manager.0.arn
  }
}

data "template_file" "clusterissuers_production" {
  template = "${file("${path.module}/templates/clusterIssuers.yaml.tpl")}"
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
    alerts = filesha1("${path.module}/resources/monitoring/alerts.yaml")
  }
}

###################################
# Default Wildcard Certificate(s) #
###################################

data "template_file" "wilcard_certificate_monitoring" {
  template = "${file("${path.module}/templates/CertificateMonitoring.yaml.tpl")}"
  vars = {
    namespace   = "monitoring"
    common_name = "*.apps.${var.cluster_domain_name}"
    alt_name    = var.is_live_cluster ? format("- '*.%s'", var.live_domain) : ""
  }
}

resource "null_resource" "wilcard_certificate_monitoring" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = "kubectl apply -f -<<EOF\n${data.template_file.wilcard_certificate_monitoring.rendered}\nEOF"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f -<<EOF\n${data.template_file.wilcard_certificate_monitoring.rendered}\nEOF"
  }

  triggers = {
    contents = sha1(data.template_file.wilcard_certificate_monitoring.rendered)
  }
}
