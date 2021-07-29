module "cert_manager" {
  source = "../"
  # "github.com/ministryofjustice/cloud-platform-terraform-certmanager?ref=1.2.1"

  iam_role_nodes      = "arn:aws:iam::000000000000:node"
  cluster_domain_name = "cert-manager.cloud-platform.service.justice.gov.uk"
  hostzone            = "AAATEST"

  dependence_prometheus = "ignore"
  dependence_opa        = "ignore"

  eks = false
}
