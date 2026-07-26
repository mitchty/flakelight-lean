{
  lib,
  src,
  config,
  flakelight,
  inputs,
  ...
}:
let
  inherit (builtins)
    fromTOML
    pathExists
    readFile
    toString
    ;
  inherit (lib)
    mkDefault
    mkIf
    mkMerge
    mkOption
    optional
    ;
  inherit (lib.fileset) fileFilter toSource unions;
  inherit (flakelight.types) fileset;

  toolchainFile = src + /lean-toolchain;
  manifestFile = src + /lake-manifest.json;
  lakefileTomlFile = src + /lakefile.toml;

  hasToolchain = pathExists toolchainFile;
  hasManifest = pathExists manifestFile;
  hasLakefileToml = pathExists lakefileTomlFile;
  hasLakefile = hasLakefileToml || pathExists (src + /lakefile.lean);

  # Try getting the Package/workspace name from lakefile.toml first as a default
  # if not specified.
  lakefileName =
    if hasLakefileToml then (fromTOML (readFile lakefileTomlFile)).name or null else null;

  assertPinned =
    value:
    assert lib.assertMsg hasToolchain ''
      No lean-toolchain file at ${toString toolchainFile}.
      Pin a Lean version first via `echo leanprover/lean4:v4.x.y > lean-toolchain`.
    '';
    assert lib.assertMsg hasManifest ''
      No lake-manifest.json file at ${toString manifestFile}.
      Generate it via `lake update` first and add it to the git index.
    '';
    value;
in
{
  options = {
    fileset = mkOption {
      type = fileset;
      default = unions (
        [
          (fileFilter (file: file.hasExt "lean") src)
          manifestFile
          toolchainFile
        ]
        ++ optional (pathExists (src + /lakefile.toml)) (src + /lakefile.toml)
        ++ optional (pathExists (src + /lakefile.lean)) (src + /lakefile.lean)
      );
    };

    lean.target = mkOption {
      type = lib.types.str;
      default = config.pname;
      description = ''
        Lake build target name to pass to lake2nix.mkPackage.
        Use this to specify the name if the auto detection is wrong, probably best to always set this.
      '';
    };

    lean.binary = mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        If lean4-nix's `readToolchainFile` fetches a prebuilt Lean
        binary toolchain aka `binary = true` or build Lean from source
        when `binary = false`.

        Defaults to `null`, which auto-detects per system: binary toolchains are
        used everywhere except Darwin. On Darwin, `install_name_tool` cannot
        relink the prebuilt `libleanshared_1.dylib` because its Mach-O load
        commands don't have enough headerpad space, so the binary toolchain
        build fails during `fixupPhase`. See
        https://github.com/lenianiva/lean4-nix/issues/76. Setting to true will
        cause that platform to build from scratch too.
      '';
    };
  };

  config = mkMerge [
    (mkIf hasLakefile {
      pname = mkDefault (if lakefileName != null then lakefileName else "lean-package");

      withOverlays = assertPinned [
        (
          final: prev:
          let
            binary =
              if config.lean.binary != null then config.lean.binary else !prev.stdenv.hostPlatform.isDarwin;
            toolchainOverlay = inputs.lean4-nix.readToolchainFile {
              toolchain = toolchainFile;
              inherit binary;
            };
          in
          toolchainOverlay final prev
        )
      ];

      package =
        { callPackage, defaultMeta }:
        assertPinned (
          let
            lake2nix = callPackage inputs.lean4-nix.lake { };
          in
          lake2nix.mkPackage {
            name = config.lean.target;
            src = toSource {
              root = src;
              inherit (config) fileset;
            };
            meta = defaultMeta;
          }
        );

      devShell.packages = pkgs: assertPinned [ pkgs.lean.lean-all ];
    })
  ];
}
