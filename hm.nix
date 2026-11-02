{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.kimi-desktop;
  hyprctlExe = lib.getExe' pkgs.hyprland "hyprctl";
  documentsDir =
    if config.xdg.userDirs.documents != null then
      config.xdg.userDirs.documents
    else
      "${config.home.homeDirectory}/Documents";
in
{
  options.programs.kimi-desktop = {
    enable = lib.mkEnableOption "Kimi Desktop";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Whether Kimi Desktop starts with the graphical session, via a systemd user service bound to `graphical-session.target`.";
    };
    hyprlandGlobalShortcut = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "F1";
      description = ''
        Key (with optional modifiers, Hyprland syntax) that invokes the launcher.
        Starts a small user service that mirrors the app's currently registered portal shortcut id into a Hyprland `global` bind:
        1) The Hyprland compositor fires portal shortcuts only through a user-declared bind, and a static declarative bind cannot follow the fresh shortcut id the app generates when its user data is reprovisioned.
        2) Record the same key in the app settings (Settings → Shortcuts).
      '';
    };
    ozonePlatform = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "x11"
          "wayland"
        ]
      );
      default = null;
      example = "x11";
      description = ''
        Electron ozone platform passed to the launcher.
        `null` follows the session and is the right choice for almost everyone.
        Set to `x11` if the app's save dialog ever crashes on Wayland — at the cost of the launcher hotkey, which needs native Wayland.
      '';
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kimi-desktop;
      defaultText = lib.literalExpression "pkgs.kimi-desktop";
      description = ''
        The kimi-desktop package to install.
        The default comes from this flake's overlay.
        `homeManagerModules.kimi-desktop` adds it to Home Manager's own nixpkgs unless `home-manager.useGlobalPkgs` is set, in which case import `nixosModules.kimi-desktop` in your system configuration so the overlay reaches the global pkgs.
      '';
    };
    workspaceDir = lib.mkOption {
      type = lib.types.str;
      default = "${documentsDir}/kimi/workspace";
      example = "~/work/kimi-workspace";
      description = ''
        Main agent workspace directory.
        Passed to daimon as `--workspace-dir` during setup/onboard (injected by the daimon shim).
        Defaults to the XDG documents directory (`xdg.userDirs.documents`), falling back to `~/Documents`; any assignment overrides it.
        Semantics: non-project tasks run in per-task run directories under the daimon share dir, while automations (cron) and project work persist their files under this workspace.
      '';
    };
    webbridgeCdpPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      example = 9223;
      description = ''
        Optional CDP port for `kimi-webbridge-chrome`.
        `null` disables Chrome remote debugging.
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs ? kimi-desktop;
        message = ''
          programs.kimi-desktop needs pkgs.kimi-desktop.
          homeManagerModules.kimi-desktop adds the overlay to Home Manager's own pkgs, which home-manager.useGlobalPkgs replaces with the system ones — import nixosModules.kimi-desktop in that case.
        '';
      }
      {
        assertion =
          cfg.hyprlandGlobalShortcut == null || (config.wayland.windowManager.hyprland.enable or false);
        message = "programs.kimi-desktop.hyprlandGlobalShortcut needs wayland.windowManager.hyprland.enable = true.";
      }
    ];
    home.packages = [ cfg.package ];
    home.sessionVariables = {
      KIMI_DESKTOP_WORKSPACE_DIR = cfg.workspaceDir;
    }
    // lib.optionalAttrs (cfg.ozonePlatform != null) {
      KIMI_DESKTOP_OZONE_PLATFORM = cfg.ozonePlatform;
    }
    // lib.optionalAttrs (cfg.webbridgeCdpPort != null) {
      KIMI_WEBBRIDGE_CDP_PORT = toString cfg.webbridgeCdpPort;
    };
    systemd.user.services = {
      kimi-desktop = lib.mkIf cfg.autostart {
        Unit = {
          Description = "Kimi Desktop";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe cfg.package;
          Restart = "on-failure";
          RestartSec = "5s";
          Environment = [
            "KIMI_DESKTOP_WORKSPACE_DIR=${cfg.workspaceDir}"
          ]
          ++ lib.optional (cfg.ozonePlatform != null) "KIMI_DESKTOP_OZONE_PLATFORM=${cfg.ozonePlatform}";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      kimi-desktop-hyprland-shortcut = lib.mkIf (cfg.hyprlandGlobalShortcut != null) {
        Unit = {
          Description = "Kimi Desktop Hyprland launcher-hotkey bind sync daemon";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.python312} ${./tools/hyprland-shortcut-sync.py}";
          Environment = [
            "KIMI_SHORTCUT_KEY=${cfg.hyprlandGlobalShortcut}"
            "HYPRCTL=${hyprctlExe}"
          ];
          Restart = "always";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
