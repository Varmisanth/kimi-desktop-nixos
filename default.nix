let
  overlay = final: _: {
    kimi-desktop = final.callPackage ./package.nix { electron = final.electron_44; };
  };
in
{
  homeManagerModules.kimi-desktop =
    args@{ lib, ... }:
    let
      globalPkgs = (args.osConfig or { }).home-manager.useGlobalPkgs or false;
    in
    {
      imports = [ ./hm.nix ];
      nixpkgs.overlays = lib.mkIf (!globalPkgs) [ overlay ];
    };
  nixosModules.kimi-desktop = {
    imports = [ ./os.nix ];
    nixpkgs.overlays = [ overlay ];
  };
  overlays.kimi-desktop = overlay;
}
