
ingressShim:
  defaultIssuerName: letsencrypt-production
  defaultIssuerKind: ClusterIssuer
  defaultACMEChallengeType: dns01
  defaultACMEDNS01ChallengeProvider: route53-cloud-platform

installCRDs: true


%{ if eks == false ~}
podAnnotations:
  iam.amazonaws.com/role: "${certmanager_role}"
%{ endif ~}

%{ if eks ~}
serviceAccount:
  create: true
  annotations: 
    eks.amazonaws.com/role-arn: "${eks_service_account}"

securityContext:
  enabled: true
  fsGroup: 1001
%{ endif ~}

prometheus:
  enabled: true
  servicemonitor:
    enabled: true