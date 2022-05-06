module "cert_manager" {
  source = "../"
  # "github.com/ministryofjustice/cloud-platform-terraform-certmanager?ref=1.2.1"

  cluster_domain_name = "cert-manager.cloud-platform.service.justice.gov.uk"
  hostzone            = ["AAATEST"]

  dependence_prometheus = "ignore"
  dependence_opa        = "ignore"
}
