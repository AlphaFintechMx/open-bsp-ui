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
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts."${cfg.domain}" = {
      forceSSL = lib.mkDefault true;
      useACMEHost = lib.mkDefault cfg.domain;
      root = cfg.rootDir;

      locations."/" = {
        tryFiles = "$uri $uri/ /index.html";
        extraConfig = ''
          limit_req zone=general_limit burst=20 nodelay;
          add_header X-Frame-Options "DENY" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        '';
      };

      locations."/assets/" = {
        extraConfig = ''
          add_header Cache-Control "public, max-age=31536000, immutable";
        '';
      };
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
