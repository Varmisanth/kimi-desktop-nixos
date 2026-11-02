{
  config,
  lib,
  pkgs,
  options,
  ...
}:
let
  cfg = config.programs.kimi-desktop;
in
{
  options.programs.kimi-desktop = {
    enable = lib.mkEnableOption "Kimi Desktop";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Whether Kimi Desktop starts with the graphical session for the managed users.";
    };
    installPackage = lib.mkOption {
      type = lib.types.bool;
      default = !(options ? home-manager) || cfg.users == [ ];
      description = ''
        Whether to install Kimi Desktop system-wide.
        Defaults to false when Home Manager is set up and `users` is non-empty, because the Home Manager module then installs it per-user instead.
      '';
    };
    ozonePlatform = lib.mkOption {
      type = lib.types.enum [
        "x11"
        "wayland"
      ];
      default = "x11";
      example = "wayland";
      description = ''
        Electron ozone platform for the managed users.
        Forwarded to the per-user module.
      '';
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kimi-desktop;
      defaultText = lib.literalExpression "pkgs.kimi-desktop";
      description = ''
        The kimi-desktop package to install.
        The default comes from this flake's overlay, which `nixosModules.kimi-desktop` adds to the system pkgs.
      '';
    };
    webbridge.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Whether to force-install the Kimi WebBridge extension in Google Chrome.";
    };
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Home Manager users to enable programs.kimi-desktop for.
        Requires the Home Manager NixOS integration.
        The per-user module is imported automatically: no manual home-manager configuration is needed.
      '';
    };
  };
  config = lib.mkIf cfg.enable (
    {
      assertions = [
        {
          assertion = pkgs ? kimi-desktop;
          message = ''
            programs.kimi-desktop needs pkgs.kimi-desktop.
            nixosModules.kimi-desktop adds the overlay to the system pkgs; with home-manager.useGlobalPkgs the Home Manager variant sees these same pkgs.
          '';
        }
      ];
      environment.etc = lib.mkIf cfg.webbridge.enable {
        "opt/chrome/policies/managed/kimi-webbridge.json".text = builtins.toJSON {
          ExtensionInstallForcelist = [
            "fldmhceldgbpfpkbgopacenieobmligc;https://clients2.google.com/service/update2/crx"
          ];
        };
      };
      environment.systemPackages = lib.mkIf cfg.installPackage [ cfg.package ];
    }
    // lib.optionalAttrs (options ? home-manager) {
      home-manager.users = lib.genAttrs cfg.users (_: {
        imports = [ ./hm.nix ];
        programs.kimi-desktop = {
          enable = true;
          inherit (cfg) autostart ozonePlatform;
        };
      });
    }
  );
}
