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

## Inputs

| Name                        | Description                                                   | Type     | Default | Required |
|-----------------------------|---------------------------------------------------------------|:--------:|:-------:|:--------:|
| dependence_prometheus       | Prometheus Dependence variable                                         | string   |         | yes |
| dependence_opa              | Priority class dependence                                              | string   |         | yes |
| iam_role_nodes              | Nodes IAM role ARN in order to create the KIAM/Kube2IAM                | string   |         | yes |
| hostzone                    | To solve ACME Challenges. Scope should be limited to hostzone. If star (*) is used certmanager will control all hostzones | string | | yes |
| cluster_domain_name         | Value used for externalDNS annotations and certmanager                 | string   |         | yes |
| eks                         | Are we deploying in EKS or not?                                        | bool     | false   | no |
| eks_cluster_oidc_issuer_url | The OIDC issuer URL from the cluster, it is used for IAM ServiceAccount integration | string     |  | no |


## Outputs

| Name | Description |
|------|-------------|
| helm_certmanager_status | This is an output used as a dependency (to know the prometheus-operator chart has been deployed) |
