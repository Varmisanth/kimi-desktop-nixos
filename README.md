<h1 align="center">
  <img src="https://www.kimi.com/pwa-192.png" alt="Kimi" width="120">
  <br><br>
  kimi-desktop-nixos
</h1>

<p align="center"><em>Kimi Desktop packaged for NixOS (unofficial port)</em></p>

<p align="center">
  <img alt="packaged" src="https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2FVarmisanth%2Fkimi-desktop-nixos%2Fmain%2Fparams.nix&search=version%20%3D%20%22%28%5B0-9.%5D%2B%29%22&replace=%241&label=packaged&color=blueviolet">
  <a href="https://www.kimi.com/en/help/kimi-work/release-notes"><img alt="upstream" src="https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fwww.kimi.com%2Fen%2Fhelp%2Fkimi-work%2Frelease-notes&search=%28%5B0-9%5D%5C.%5B0-9%5D%2B%5C.%5B0-9%5D%2B%29%20%5C(&replace=%241&label=upstream&color=informational"></a>
  <img alt="check" src="https://img.shields.io/github/actions/workflow/status/Varmisanth/kimi-desktop-nixos/check.yml?branch=main&label=check">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue.svg">
  <img alt="updated" src="https://img.shields.io/github/last-commit/Varmisanth/kimi-desktop-nixos?label=updated">
  <a href="https://varmisanth.cachix.org"><img alt="cachix" src="https://img.shields.io/badge/cachix-varmisanth-blue.svg"></a>
</p>

## Quickstart via Flakes on NixOS

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    kimi-desktop-nixos = {
      url = "github:Varmisanth/kimi-desktop-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, kimi-desktop-nixos, ... }: {
    nixosConfigurations.alice = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        kimi-desktop-nixos.nixosModules.kimi-desktop
        {
          programs.kimi-desktop = {
            enable = true;
            users = [ "alice" ];
          };
        }
      ];
    };
  };
}
```

Users listed in `users` receive the Home Manager module.

The module installs `kimi-desktop` per-user.

Set `programs.kimi-desktop.installPackage = true` to also install the package system-wide.

`users` requires the Home Manager NixOS module.

## Via Home Manager with Flakes

Alternative to the NixOS module — installs `Kimi Desktop` per-user.

Works integrated with NixOS or as a standalone flake.

**Standalone Home Manager on NixOS:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kimi-desktop-nixos = {
      url = "github:Varmisanth/kimi-desktop-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { home-manager, nixpkgs, kimi-desktop-nixos, ... }: {
    homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
      modules = [
        kimi-desktop-nixos.homeManagerModules.kimi-desktop
        { programs.kimi-desktop.enable = true; }
      ];
    };
  };
}
```

> [!NOTE]
>
> With `home-manager.useGlobalPkgs = true`, Home Manager sees the system pkgs.
>
> Also import `nixosModules.kimi-desktop` in your NixOS configuration.
>
> The overlay must reach the pkgs the HM module reads `pkgs.kimi-desktop` from.

## First launch

Start `kimi-desktop` from the application menu or a terminal.

Sign in on first launch.

First start provisions the daimon agent.

It sets up the managed Python runtime, skills, and workspace.

It needs network and is not instant.

## Options

### Home Manager module — `programs.kimi-desktop`

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | `kimi-desktop` per-user |
| `autostart` | bool | `false` | Start with the session |
| `hyprlandGlobalShortcut` | nullOr str | `null` | Hyprland launcher hotkey |
| `ozonePlatform` | nullOr enum | `null` | Electron ozone platform<br>`null` follows the session<br>`"wayland"` or `"x11"`<br>See [Known issues](#known-issues) |
| `package` | package | `pkgs.kimi-desktop` | The package to install |
| `workspaceDir` | str | `xdg.userDirs.documents`<br>+ `/kimi/workspace` | Main agent workspace<br>Automations persist here<br>Projects persist here<br>Defaults to `~/Documents` |
| `webbridgeCdpPort` | nullOr port | `null` | Optional CDP port<br>`null` disables debugging |

### NixOS module — `programs.kimi-desktop`

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable the system-side module |
| `autostart` | bool | `false` | Forwarded to the per-user module |
| `installPackage` | bool | auto | Install system-wide<br>Off when HM and `users` are set |
| `ozonePlatform` | nullOr enum | `null` | Forwarded to the per-user module<br>`"wayland"` or `"x11"`<br>See [Known issues](#known-issues) |
| `package` | package | `pkgs.kimi-desktop` | The package to install |
| `webbridge.enable` | bool | `true` | Force-install the WebBridge extension<br>Applies to Google Chrome |
| `users` | list of str | `[]` | Users receiving the HM module<br>No manual home-manager wiring |

### Outputs

| Output | Description |
|---|---|
| `nixosModules.kimi-desktop` | NixOS module |
| `homeManagerModules.kimi-desktop` | Home Manager module |
| `overlays.kimi-desktop` | Overlay exposing `pkgs.kimi-desktop` |
| `packages.<system>.kimi-desktop` | `kimi-desktop` package |

## Known issues

- **Launcher global hotkey.**

  Wayland uses the XDG GlobalShortcuts portal.

  KDE, GNOME, and COSMIC support it out of the box.

  On Hyprland, set:

  ```nix
  programs.kimi-desktop.hyprlandGlobalShortcut = "F1";
  ```

  `"F1"` is only an example.

  Any key works — pick one that does not collide with your binds.

  Record the same key in Settings → Shortcuts.

  On X11, Electron grabs the key natively via `XGrabKey`.
- **Save dialog crash on Wayland.**

  Downloading a file crashes the whole app on Wayland.

  The main process dies with `SIGTRAP`.

  Chromium aborts on `zxdg_exporter_v2: surface must be an xdg_toplevel`.

  Set `programs.kimi-desktop.ozonePlatform = "x11";` to render through XWayland.

  That renders downloads usable.

  Note the trade-off: the launcher hotkey needs native Wayland.

  Under `x11` the app never registers its portal shortcut.
- **Transient 401 on token expiry.**

  The OAuth access token lives about 15–20 minutes.

  A request may catch a stale in-memory token.

  The app then re-provisions itself within about 3 seconds.

  A persistent 401 usually means the app needs to be signed in again.
- **Electron sandbox.**

  Kimi Desktop launches with `--no-sandbox`.

  This is an intentional NixOS packaging trade-off.

  The Chromium sandbox helper cannot be installed setuid from the Nix store in this configuration.

  This weakens renderer isolation.

  Treat remote content and installed plugins accordingly.
- **WebBridge browser automation.**

  The package includes the official static Linux daemon.

  The `kimi-webbridge-chrome` launcher opens Chrome with an isolated profile.

  The profile lives under `~/.local/state/kimi-desktop/webbridge-chrome`.

  `$XDG_STATE_HOME/kimi-desktop/webbridge-chrome` replaces the default when set.

  The extension itself is force-installed into every Chrome profile, including the main one.

  It connects to the daemon from the browser you already use.

  The separate profile exists because Chrome refuses remote debugging on the default profile.

  It also keeps agent-driven browsing out of the signed-in session.

  The NixOS module force-installs the official extension by default.

  Set `programs.kimi-desktop.webbridge.enable = false;` to disable that policy.

  CDP debugging is disabled by default.

  Set `programs.kimi-desktop.webbridgeCdpPort = 9223;` to opt in declaratively.

  Set `KIMI_WEBBRIDGE_CDP_PORT` for a one-off run.

  The direct launcher does not depend on the desktop's `External browser` toggle.

  Browser automation still requires a graphical browser session.

## Binary Cache

Pre-built artifacts live in [`varmisanth.cachix.org`](https://app.cachix.org/cache/varmisanth), pushed by CI on every commit to `main`.

Add the substituter to your own configuration to use them:

```nix
nix.settings = {
  substituters = [ "https://varmisanth.cachix.org" ];
  trusted-public-keys = [ "varmisanth.cachix.org-1:rt04yjDDJKDWe+h6B1XQWfdsSDUX6uks+9IKVBjn2d8=" ];
};
```

The `nixConfig` block in this flake does not reach you when the module is consumed as an input.

Nix reads `nixConfig` only from the flake it evaluates directly.

A system flake that lists this repository under `inputs` never sees it and builds from source.

The manual entry above is the only reliable way to get the cache.

It needs nothing else — it is system configuration.

Only the `nixConfig` route depends on `trusted-users`.

## License

[MIT](LICENSE) — packaging code only.

Moonshot AI binaries and assets remain property of Moonshot AI.

This repository neither hosts nor redistributes them.

## Acknowledgments

[Kimi Desktop](https://www.kimi.com/) is by Moonshot AI.

Packaged with help from [Kimi Code](https://github.com/MoonshotAI/kimi-code).
