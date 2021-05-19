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
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13 |

## Providers

| Name | Version |
|------|---------|
| aws | n/a |
| helm | n/a |
| kubernetes | n/a |
| null | n/a |
| template | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| iam_assumable_role_admin | terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc | 3.13.0 |

## Resources

| Name |
|------|
| [aws_iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) |
| [aws_iam_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) |
| [aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) |
| [aws_iam_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) |
| [helm_release](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) |
| [kubernetes_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) |
| [null_resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) |
| [template_file](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster\_domain\_name | The cluster domain used for externalDNS annotations and certmanager | `any` | n/a | yes |
| eks | Where are you applying this modules in kOps cluster or in EKS (KIAM or KUBE2IAM?) | `bool` | `false` | no |
| eks\_cluster\_oidc\_issuer\_url | If EKS variable is set to true this is going to be used when we create the IAM OIDC role | `string` | `""` | no |
| hostzone | In order to solve ACME Challenges certmanager creates DNS records. We should limit the scope to certain hostzone. If star (*) is used certmanager will control all hostzones | `list(string)` | n/a | yes |
| iam\_role\_nodes | Nodes IAM role ARN in order to create the KIAM/Kube2IAM | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| helm\_cert\_manager\_status | n/a |

<!--- END_TF_DOCS --->

