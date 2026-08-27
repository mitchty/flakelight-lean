# flakelight-lean: Stupid simple Lean 4 module for flakelight abuse
# SPDX-License-Identifier: BlueOak-1.0.0

{
  description = "Lean 4 module for flakelight";
  inputs.flakelight-treefmt.inputs.flakelight.follows = "flakelight";

  outputs =
    {
      self,
      flakelight,
      lean4-nix,
      flakelight-treefmt,
      flakelight-mitchty,
      ...
    }:
    let
      treefmtDefaults = {
        imports = [
          flakelight-treefmt.flakelightModules.default
          flakelight-mitchty.flakelightModules.default
        ];
        treefmtConfig = {
          programs.prettier.enable = true;
          programs.taplo.enable = true;

          settings.global.excludes = [
            "lake-manifest.json"
            "*.lean"
          ];
        };
      };
    in
    flakelight ./. {
      imports = [
        flakelight.flakelightModules.extendFlakelight
        treefmtDefaults
      ];
      inputs.self = self;
      nixDir = ./.;

      # These are the default systems this works on. Flakes that import
      # flakelight-lean.nix as a module need to set `systems` themselves. I run
      # on both macos and linux to test in ci too.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      flakelightModule = { lib, ... }: {
        imports = [
          ./flakelight-lean.nix
          treefmtDefaults
        ];
        inputs.lean4-nix = lib.mkDefault lean4-nix;
      };

      devShell.packages = pkgs: [ pkgs.nixd ];
    };
  inputs = {
    flakelight.url = "github:nix-community/flakelight";
    lean4-nix.url = "github:lenianiva/lean4-nix";
    flakelight-treefmt.url = "github:m15a/flakelight-treefmt";
    flakelight-mitchty = {
      url = "github:mitchty/flakelight-mitchty";
      inputs.flakelight.follows = "flakelight";
    };
  };
}
