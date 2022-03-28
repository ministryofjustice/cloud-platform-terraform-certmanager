
ingressShim:
  defaultIssuerName: letsencrypt-production
  defaultIssuerKind: ClusterIssuer
  defaultACMEChallengeType: dns01
  defaultACMEDNS01ChallengeProvider: route53-cloud-platform

installCRDs: true

serviceAccount:
  create: true
  annotations: 
    eks.amazonaws.com/role-arn: "${eks_service_account}"

securityContext:
  enabled: true
  fsGroup: 1001

prometheus:
  enabled: true
  servicemonitor:
    enabled: true
