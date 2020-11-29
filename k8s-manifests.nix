{ imageName ? "kierdavis/bella", imageTag ? "latest" }:

let
  nixpkgs = import <nixpkgs> {};
  lib = nixpkgs.lib;

  image = "${imageName}:${imageTag}";
  commonLabels = { app = "bella"; };
  
  mkDataHash = data: builtins.substring 0 6 (builtins.hashString "sha1" (builtins.toJSON data));
  serviceHostname = s: "${s.metadata.name}.${s.metadata.namespace}.svc.cluster.local";
  servicePorts = s: builtins.listToAttrs (builtins.map (p: { inherit (p) name; value = p.port; }) s.spec.ports);
  servicePort = s: pn: (servicePorts s)."${pn}";
  serviceHostPort = s: pn: "${serviceHostname s}:${builtins.toString (servicePort s pn)}";

  environment = { namespace, secrets, djangoDebug }: builtins.filter (x: x ? kind) (lib.attrValues rec {
    baseDjangoContainer = {
      inherit image;
      envFrom = [
        { configMapRef.name = configMap.metadata.name; }
        { secretRef.name = secret.metadata.name; }
      ];
      env = lib.optional djangoDebug { name = "DJANGO_DEBUG"; value = "yes"; };
    };

    configMap = rec {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        labels = commonLabels // { version = mkDataHash data; };
        name = with metadata.labels; "${app}-${version}";
        inherit namespace;
      };
      data = {
        DJANGO_ALLOWED_HOSTS = serviceHostname djangoService;
        POSTGRES_HOST = serviceHostname postgresService;
        POSTGRES_PORT = builtins.toString (servicePort postgresService "postgres");
        POSTGRES_USER = "postgres";
        POSTGRES_DB = "bella";
        AWS_ACCESS_KEY_ID = "bella";
        AWS_S3_ENDPOINT_URL = "http://${serviceHostPort minioService "minio"}/";
        AWS_STORAGE_BUCKET_NAME = "bella";
      };
    };
    secret = rec {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        labels = commonLabels // { version = mkDataHash data; };
        name = with metadata.labels; "${app}-${version}";
        inherit namespace;
      };
      data = {
        DJANGO_SECRET_KEY = secrets.django.base64;
        POSTGRES_PASSWORD = secrets.postgres.base64;
        AWS_SECRET_ACCESS_KEY = secrets.minio.base64;
      };
    };
    postgresService = rec {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        labels = commonLabels // { component = "postgres"; };
        name = with metadata.labels; "${app}-${component}";
        inherit namespace;
      };
      spec = {
        selector = postgresStatefulSet.spec.template.metadata.labels;
        ports = [{
          name = "postgres";
          port = 5432;
          targetPort = "postgres";
          protocol = "TCP";
        }];
      };
    };
    postgresStatefulSet = rec {
      apiVersion = "apps/v1";
      kind = "StatefulSet";
      metadata = {
        inherit (postgresService.metadata) name namespace labels;
      };
      spec = {
        selector.matchLabels = spec.template.metadata.labels;
        serviceName = postgresService.metadata.name;
        replicas = 1;
        template = {
          metadata.labels = metadata.labels;
          spec = {
            nodeSelector."kubernetes.io/hostname" = "beagle2";
            containers = [{
              name = "postgres";
              image = "postgres:13";
              env = [
                { name = "POSTGRES_USER"; valueFrom.configMapKeyRef = { inherit (configMap.metadata) name; key = "POSTGRES_USER"; }; }
                { name = "POSTGRES_PASSWORD"; valueFrom.secretKeyRef = { inherit (secret.metadata) name; key = "POSTGRES_PASSWORD"; }; }
                { name = "POSTGRES_DB"; valueFrom.configMapKeyRef = { inherit (configMap.metadata) name; key = "POSTGRES_DB"; }; }
              ];
              volumeMounts = [{
                name = "data";
                mountPath = "/var/lib/postgresql/data";
              }];
              ports = [{
                name = "postgres";
                containerPort = 5432;
                protocol = "TCP";
              }];
            }];
            volumes = [{
              name = "data";
              hostPath.path = "/home/k8s/${metadata.namespace}/${metadata.name}";
            }];
          };
        };
      };
    };
    minioService = rec {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        labels = commonLabels // { component = "minio"; };
        name = with metadata.labels; "${app}-${component}";
        inherit namespace;
      };
      spec = {
        selector = minioStatefulSet.spec.template.metadata.labels;
        ports = [{
          name = "minio";
          port = 80;
          targetPort = "minio";
          protocol = "TCP";
        }];
      };
    };
    minioStatefulSet = rec {
      apiVersion = "apps/v1";
      kind = "StatefulSet";
      metadata = {
        inherit (minioService.metadata) name namespace labels;
      };
      spec = {
        selector.matchLabels = spec.template.metadata.labels;
        serviceName = minioService.metadata.name;
        replicas = 1;
        template = {
          metadata.labels = metadata.labels;
          spec = {
            nodeSelector."kubernetes.io/hostname" = "beagle2";
            containers = [{
              name = "minio";
              image = "minio/minio";
              args = ["server" "/data"];
              env = [
                { name = "MINIO_ACCESS_KEY"; valueFrom.configMapKeyRef = { inherit (configMap.metadata) name; key = "AWS_ACCESS_KEY_ID"; }; }
                { name = "MINIO_SECRET_KEY"; valueFrom.secretKeyRef = { inherit (secret.metadata) name; key = "AWS_SECRET_ACCESS_KEY"; }; }
              ];
              volumeMounts = [{
                name = "data";
                mountPath = "/data";
              }];
              ports = [{
                name = "minio";
                containerPort = 9000;
                protocol = "TCP";
              }];
            }];
            volumes = [{
              name = "data";
              hostPath.path = "/home/k8s/${metadata.namespace}/${metadata.name}";
            }];
          };
        };
      };
    };
    djangoService = rec {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        labels = commonLabels // { component = "django"; };
        name = "bella";
        inherit namespace;
      };
      spec = {
        selector = djangoDeployment.spec.template.metadata.labels;
        ports = [{
          name = "http";
          port = 80;
          targetPort = "http";
          protocol = "TCP";
        }];
      };
    };
    djangoDeployment = rec {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        inherit (djangoService.metadata) name namespace labels;
      };
      spec = {
        selector.matchLabels = spec.template.metadata.labels;
        replicas = 1;
        template = {
          metadata.labels = metadata.labels;
          spec = let
          in {
            initContainers = [(baseDjangoContainer // {
              name = "migrate";
              command = ["manage" "migrate"];
            })];
            containers = [(baseDjangoContainer // {
              name = "django";
              ports = [{
                name = "http";
                containerPort = 8000;
                protocol = "TCP";
              }];
            })];
          };
        };
      };
    };
    storagegcCronJob = rec {
      apiVersion = "batch/v1beta1";
      kind = "CronJob";
      metadata = {
        labels = commonLabels // { component = "storagegc"; };
        name = with metadata.labels; "${app}-${component}";
        inherit namespace;
      };
      spec = {
        schedule = "40 * * * *";
        jobTemplate.spec.template.spec = {
          containers = [(baseDjangoContainer // {
            name = "storagegc";
            command = ["manage" "storagegc"];
          })];
          restartPolicy = "OnFailure";
        };
      };
    };
  });

in {
  dev = environment { namespace = "kier-dev"; secrets = (import ./secrets.nix).dev; djangoDebug = true; };
  prod = environment { namespace = "kier"; secrets = (import ./secrets.nix).prod; djangoDebug = false; };
}
