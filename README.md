# cloud-platform-terraform-certmanager

Terraform module that deploys cloud-platform certmanager

## Usage

```hcl
module "cert_manager" {
  source = "github.com/ministryofjustice/cloud-platform-terraform-certmanager?ref=0.0.1"

  iam_role_nodes      = data.aws_iam_role.nodes.arn
  cluster_domain_name = data.terraform_remote_state.cluster.outputs.cluster_domain_name
  hostzone            = terraform.workspace == local.live_workspace ? "*" : data.terraform_remote_state.cluster.outputs.hosted_zone_id

  # This module requires helm and OPA already deployed
  dependence_prometheus  = module.prometheus.helm_prometheus_operator_status
  dependence_opa         = module.opa.helm_opa_status

  # This section is for EKS
  eks                         = true
  eks_cluster_oidc_issuer_url = data.terraform_remote_state.cluster.outputs.cluster_oidc_issuer_url
}
```

<!--- BEGIN_TF_DOCS --->

<!--- END_TF_DOCS --->

