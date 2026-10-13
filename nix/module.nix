{ pkgs, config, lib, ...}:
let
  cfg = config.open-bsp-ui;
in
{
  options = {
    open-bsp-ui = {
      enable = lib.mkEnableOption "Enable OpenBSP UI web client";

      domain = lib.mkOption {
        type = lib.types.str;
        default = "wa.alphapm.mx";
        description = "Domain name for OpenBSP UI Nginx virtual host";
      };

      rootDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/alpha/open-bsp-ui/dist";
        description = "Path to the built SPA dist directory on the host";
      };

      appDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/alpha/open-bsp-ui";
        description = "Directory where the application is deployed";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "alpha";
        description = "User for the application files";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "users";
        description = "Group for the application files";
      };

      plausible = {
        enable = lib.mkEnableOption "Enable Plausible analytics proxy on Nginx";
        domain = lib.mkOption {
          type = lib.types.str;
          default = "plausible.alphapm.mx";
          description = "Domain of the Plausible Analytics server";
        };
        upstream = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:8007";
          description = "Internal upstream URL for Plausible Analytics server";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts."${cfg.domain}" = {
      forceSSL = lib.mkDefault true;
      useACMEHost = lib.mkDefault cfg.domain;
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
      } // (lib.optionalAttrs cfg.plausible.enable {
        "= /js/script.js" = {
          proxyPass = "${cfg.plausible.upstream}/js/script.js";
          extraConfig = ''
            proxy_set_header Host "${cfg.plausible.domain}";
            proxy_buffering on;
          '';
        };
        "= /api/event" = {
          proxyPass = "${cfg.plausible.upstream}/api/event";
          extraConfig = ''
            proxy_set_header Host "${cfg.plausible.domain}";
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_buffering on;
          '';
        };
      });
    };

    environment.systemPackages = [
      (pkgs.callPackage ./update-open-bsp-ui.nix {})
      pkgs.nodejs
    ];

    systemd.tmpfiles.rules = [
      "z ${cfg.appDir} 0755 ${cfg.user} ${cfg.group} -"
      "Z ${cfg.rootDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Symlink .env if available in stack-global
    system.userActivationScripts.linkOpenBspUiEnv.text = ''
      if [ ! -f "${cfg.appDir}/.env" ] && [ -f "/home/alpha/stack-global/env/open-bsp-ui/.env" ]; then
        ln -sf "/home/alpha/stack-global/env/open-bsp-ui/.env" "${cfg.appDir}/.env"
      fi
    '';
  };
}
