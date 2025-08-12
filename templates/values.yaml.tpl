
ingressShim:
  defaultIssuerName: letsencrypt-production
  defaultIssuerKind: ClusterIssuer

installCRDs: true

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
  