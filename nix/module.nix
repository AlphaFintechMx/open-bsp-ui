{ config, lib, pkgs, ... }:
let
  cfg = config.services.open-bsp-ui;
  allDomains = [ cfg.domain ] ++ cfg.extraDomains;
in
{
  options.services.open-bsp-ui = {
    enable = lib.mkEnableOption "OpenBSP UI web client";

    user = lib.mkOption {
      type = lib.types.str;
      default = "alpha";
      description = "System user owning the deployment directory.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "System group owning the deployment directory.";
    };

    appDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}/open-bsp-ui";
      defaultText = lib.literalExpression ''"/home/''${config.services.open-bsp-ui.user}/open-bsp-ui"'';
      description = "Directory where the OpenBSP UI application is deployed.";
    };

    rootDir = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.appDir}/dist";
      defaultText = lib.literalExpression ''"''${config.services.open-bsp-ui.appDir}/dist"'';
      description = "Path to the built SPA dist directory served by Nginx.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "wa.alphapm.mx";
      description = "Primary domain name for the OpenBSP UI Nginx virtual host.";
    };

    extraDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional domains routed to the OpenBSP UI web client.";
    };

    nginx = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to configure Nginx virtual hosts for OpenBSP UI.";
      };

      forceSSL = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to force HTTPS redirection on Nginx virtual hosts.";
      };

      useACMEHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "ACME certificate host name to use for TLS; defaults to each virtual host domain when null.";
      };
    };

    plausible = {
      enable = lib.mkEnableOption "Plausible analytics proxy on Nginx";

      domain = lib.mkOption {
        type = lib.types.str;
        default = "plausible.alphapm.mx";
        description = "Domain of the Plausible Analytics server.";
      };

      upstream = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8007";
        description = "Internal upstream URL for the Plausible Analytics server.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts = lib.mkIf cfg.nginx.enable (
      lib.genAttrs allDomains (
        d:
        {
          forceSSL = lib.mkDefault cfg.nginx.forceSSL;
          useACMEHost = lib.mkDefault (if cfg.nginx.useACMEHost != null then cfg.nginx.useACMEHost else d);
          root = cfg.rootDir;

          locations = {
            "/" = {
              tryFiles = "$uri $uri/ /index.html";
              extraConfig = ''
                limit_req zone=general_limit burst=20 nodelay;
                add_header X-Frame-Options "DENY" always;
                add_header X-Content-Type-Options "nosniff" always;
                add_header Referrer-Policy "strict-origin-when-cross-origin" always;
              '';
            };

            "/assets/" = {
              extraConfig = ''
                add_header Cache-Control "public, max-age=31536000, immutable";
              '';
            };
          };
        }
        // lib.optionalAttrs cfg.plausible.enable {
          enablePlausibleProxy = true;
          plausibleDomain = cfg.plausible.domain;
          plausibleUpstream = cfg.plausible.upstream;
        }
      )
    );

    environment.systemPackages = [
      (pkgs.callPackage ./update-open-bsp-ui.nix { })
      pkgs.nodejs
    ];

    systemd.tmpfiles.rules = [
      "z ${cfg.appDir} 0755 ${cfg.user} ${cfg.group} -"
      "Z ${cfg.rootDir} 0755 ${cfg.user} ${cfg.group} -"
    ];
  };
}
