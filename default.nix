{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  stuff = rec {
    src = pkgs.nix-gitignore.gitignoreSource [] ./django;
    python = pkgs.python3.override {
      packageOverrides = self: super: {
        # Remove once latest django_3 in nixpkgs is >3.1.3
        django_3 = super.django_3.overrideAttrs (oldAttrs: {
          src = pkgs.fetchFromGitHub {
            owner = "django";
            repo = "django";
            rev = "162765d6c3182e36095d29543e21b44b908625fc";
            sha256 = "1ah5q2qgrk6si43gykn0qwri2544phjlxk7579sx33a69i2pmfgm";
          };
        });
        django = self.django_3;

        black = super.black.overrideAttrs (oldAttrs: {
          patches = ({ patches = []; } // oldAttrs).patches ++ [ ./black-two-space.patch ];
          doInstallCheck = false;
        });
        aspy-refactor-imports = self.buildPythonPackage rec {
          pname = "aspy.refactor_imports";
          version = "2.1.1";
          src = self.fetchPypi {
            inherit pname version;
            sha256 = "1icmx3dfxxljn45cxlgpmhagph9hl0cxk6jqigxlzxpd7fkx3j7f";
          };
          propagatedBuildInputs = [ self.cached-property ];
        };
        reorder-python-imports = self.buildPythonPackage rec {
          pname = "reorder_python_imports";
          version = "2.3.6";
          src = self.fetchPypi {
            inherit pname version;
            sha256 = "06yjqwmqiviyi1j29s5a4p57fsg48v83qf3v8a87yvjkaci6v89f";
          };
          propagatedBuildInputs = [ self.aspy-refactor-imports ];
        };
      };
    };
    runtimePyDeps = with python.pkgs; [
      boto3
      django
      django-storages
      psycopg2
    ];
    runtimePython = python.withPackages (_: runtimePyDeps);
    develPyDeps = runtimePyDeps ++ (with python.pkgs; [
      black
      reorder-python-imports
    ]);
    develPython = python.withPackages (_: develPyDeps);
    manage = pkgs.writeShellScriptBin "manage" ''
      cd ${src}
      export DJANGO_SETTINGS_MODULE=bella.settings
      exec ${runtimePython}/bin/python manage.py "$@"
    '';
    static = pkgs.runCommand "static" {} ''
      export DJANGO_SECRET_KEY=dummy
      export DJANGO_STATIC_ROOT="$out"
      ${manage}/bin/manage collectstatic
    '';
    uwsgi = pkgs.uwsgi.override {
      plugins = ["python3"];
      python3 = python;
    };
    uwsgiIni = pkgs.writeText "uwsgi.ini" ''
      [uwsgi]
      http=0.0.0.0:8000
      module=bella.wsgi:application
      plugins=python3
      static-map=/static=${static}
    '';
    serve = pkgs.writeShellScriptBin "serve" ''
      cd ${src}
      export DJANGO_SETTINGS_MODULE=bella.settings
      export PYTHONPATH=${src}:${python.pkgs.makePythonPath runtimePyDeps}
      exec ${uwsgi}/bin/uwsgi --ini ${uwsgiIni}
    '';
    imageName = "kierdavis/bella";
    streamImage = pkgs.dockerTools.streamLayeredImage {
      name = imageName;
      tag = "latest";
      contents = [
        serve
        manage
        runtimePython
        pkgs.dumb-init
      ];
      config = {
        Entrypoint = [ "dumb-init" ];
        Cmd = [ "serve" ];
        Env = [ "DJANGO_SETTINGS_MODULE=bella.settings" ];
      };
    };
    manifests = { imageTag, env }: (import ./k8s-manifests.nix { inherit imageName imageTag; })."${env}";
    manifestsJSON = let
      renderOne = manifest: ''
        ${pkgs.jq}/bin/jq > $out/${manifest.metadata.name}-${lib.strings.toLower manifest.kind}.json <<EOF
        ${builtins.toJSON manifest}
        EOF
      '';
      renderMany = manifests: ''
        mkdir -p $out
        ${lib.concatMapStringsSep "\n" renderOne manifests}
      '';
    in { imageTag, env }: pkgs.runCommand "manifests-${env}" {} (renderMany (manifests { inherit imageTag env; }));
    scripts = pkgs.buildEnv {
      name = "scripts";
      paths = lib.attrValues rec {
        pushImage = pkgs.writeShellScriptBin "push-image" ''
          set -o errexit -o nounset -o pipefail
          tag=$(date +%Y%m%dT%H%M%S)
          $(${pkgs.nix}/bin/nix-build ./default.nix -A streamImage) | ${pkgs.podman}/bin/podman load ${imageName}:$tag >&2
          ${pkgs.podman}/bin/podman push ${imageName}:$tag >&2
          ${pkgs.podman}/bin/podman untag ${imageName}:$tag >&2
          echo $tag
        '';
        generateManifests = pkgs.writeShellScriptBin "generate-manifests" ''
          set -o errexit -o nounset -o pipefail
          env=$1
          tag=$2
          ${pkgs.nix}/bin/nix-build -E '((import ./default.nix {}).manifestsJSON { env = "'$env'"; imageTag = "'$tag'"; })'
        '';
        deploy = pkgs.writeShellScriptBin "deploy" ''
          set -o errexit -o nounset -o pipefail
          env=$1
          tag=$2
          ${pkgs.kubectl}/bin/kubectl apply -f $(${generateManifests}/bin/generate-manifests $env $tag)
        '';
        deployLatestToDev = pkgs.writeShellScriptBin "deploy-latest-to-dev" ''
          set -o errexit -o nounset -o pipefail
          tag=$(${pushImage}/bin/push-image)
          ${deploy}/bin/deploy dev $tag >&2
          echo $tag
        '';
        manage = pkgs.writeShellScriptBin "manage" ''
          set -o errexit -o nounset -o pipefail
          cd django
          exec ${develPython}/bin/python manage.py "$@"
        '';
        lint = pkgs.writeShellScriptBin "lint" ''
          set -o errexit -o nounset -o pipefail
          ${develPython}/bin/black --line-length=100 django
          ${develPython}/bin/reorder-python-imports $(${pkgs.ripgrep}/bin/rg --files --glob '*.py' django)
        '';
      };
    };
    shell = let devSecrets = (import ./secrets.nix).dev; in pkgs.mkShell {
      buildInputs = with pkgs; [
        develPython
        minio-client
        postgresql_13
        scripts
      ];
      passthru = stuff;
      DJANGO_SECRET_KEY = devSecrets.django.plain;
      DJANGO_DEBUG = "yes";
      DJANGO_ALLOWED_HOSTS = "localhost";
      POSTGRES_HOST = "bella-postgres.kier-dev.svc.cluster.local";
      POSTGRES_PORT = "5432";
      POSTGRES_USER = "postgres";
      POSTGRES_PASSWORD = devSecrets.postgres.plain;
      POSTGRES_DB = "bella";
      AWS_ACCESS_KEY_ID = "bella";
      AWS_SECRET_ACCESS_KEY = devSecrets.minio.plain;
      AWS_S3_ENDPOINT_URL = "http://bella-minio.kier-dev.svc.cluster.local/";
      AWS_STORAGE_BUCKET_NAME = "bella";
    };
  };
in stuff.shell
