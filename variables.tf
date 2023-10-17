variable "dependence_prometheus" {
  description = "Prometheus module dependences in order to be executed."
}

variable "cluster_domain_name" {
  description = "The cluster domain used for externalDNS annotations and certmanager"
}

variable "hostzone" {
  description = "In order to solve ACME Challenges certmanager creates DNS records. We should limit the scope to certain hostzone. If star (*) is used certmanager will control all hostzones"
  type        = list(string)
}


variable "eks_cluster_oidc_issuer_url" {
  description = "If EKS variable is set to true this is going to be used when we create the IAM OIDC role"
  type        = string
  default     = ""
}
