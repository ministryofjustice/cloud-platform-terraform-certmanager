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
      "cloud-platform-out-of-hours-alert"                           = "true"
    }
  }
}

resource "helm_release" "cert_manager" {
  name          = "cert-manager"
  chart         = "cert-manager"
  repository    = "https://charts.jetstack.io"
  namespace     = kubernetes_namespace.cert_manager.id
  version       = "v1.7.2"
  recreate_pods = true

  values = [templatefile("${path.module}/templates/values.yaml.tpl", {
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

resource "time_sleep" "wait_60_seconds" {
  depends_on = [helm_release.cert_manager]

  create_duration = "60s"
}

data "template_file" "clusterissuers_staging" {
  template = file("${path.module}/templates/clusterIssuers.yaml.tpl")
  vars = {
    env         = "staging"
    acme_server = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }
}

data "template_file" "clusterissuers_production" {
  template = file("${path.module}/templates/clusterIssuers.yaml.tpl")
  vars = {
    env         = "production"
    acme_server = "https://acme-v02.api.letsencrypt.org/directory"
  }
}

resource "kubectl_manifest" "clusterissuers_staging" {
  yaml_body = data.template_file.clusterissuers_staging.rendered

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "clusterissuers_production" {
  yaml_body = data.template_file.clusterissuers_production.rendered

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "monitoring" {
  yaml_body = file("${path.module}/resources/alerts.yaml")

  depends_on = [helm_release.cert_manager]
}
