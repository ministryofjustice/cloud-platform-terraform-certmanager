resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"

    labels = {
      "name"                                           = "cert-manager"
      "component"                                      = "cert-manager"
      "cloud-platform.justice.gov.uk/environment-name" = "production"
      "cloud-platform.justice.gov.uk/is-production"    = "true"
      "certmanager.k8s.io/disable-validation"          = "true"
      "pod-security.kubernetes.io/enforce"             = "privileged"
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
  version       = "v1.13.1"
  recreate_pods = true

  values = [templatefile("${path.module}/templates/values.yaml.tpl", {
    eks_service_account = module.iam_assumable_role_admin.this_iam_role_arn
  })]

  lifecycle {
    ignore_changes = [keyring]
  }
}

resource "kubectl_manifest" "clusterissuers_staging" {
  yaml_body = templatefile("${path.module}/templates/clusterIssuers.yaml.tpl", {
    env         = "staging"
    acme_server = "https://acme-staging-v02.api.letsencrypt.org/directory"
  })

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "clusterissuers_production" {
  yaml_body = templatefile("${path.module}/templates/clusterIssuers.yaml.tpl", {
    env         = "production"
    acme_server = "https://acme-v02.api.letsencrypt.org/directory"
  })

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "clusterissuer_selfsigned" {
  yaml_body = file("${path.module}/templates/clusterIssuer-selfsigned.yaml")

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "monitoring" {
  yaml_body = file("${path.module}/resources/alerts.yaml")

  depends_on = [helm_release.cert_manager]
}
