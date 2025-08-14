
ingressShim:
  defaultIssuerName: letsencrypt-production
  defaultIssuerKind: ClusterIssuer

# This option is equivalent to setting crds.enabled=true and crds.keep=true.
# Deprecated: use crds.enabled and crds.keep instead.
# installCRDs: true

crds:
  # This option decides if the CRDs should be installed
  # as part of the Helm installation.
  enabled: true
 
  # This option makes it so that the "helm.sh/resource-policy": keep
  # annotation is added to the CRD. This will prevent Helm from uninstalling
  # the CRD when the Helm release is uninstalled.
  # WARNING: when the CRDs are removed, all cert-manager custom resources
  # (Certificates, Issuers, ...) will be removed too by the garbage collector.
  keep: true

serviceAccount:
  create: true
  annotations: 
    eks.amazonaws.com/role-arn: "${eks_service_account}"

securityContext:
  fsGroup: 1001

prometheus:
  enabled: true
  servicemonitor:
    enabled: true

replicaCount: "${certman_replicas}"

webhook:
  replicaCount: "${webhook_replicas}"

cainjector:
  replicaCount: "${cainjector_replicas}"
  