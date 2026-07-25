# Minimal example showing how to use this flakelight module
#
# Note for ci reasons and to force downstream users to be explicit about their
# own nix dependencies, there is no flake.lock file provided for the example
# itself.
#
# You'll be updating the url anyway...
{
  description = "flakelight-lean minimal example";
  inputs = {
    flakelight.url = "github:nix-community/flakelight";
    flakelight-lean.url = "path:../..";
  };
  outputs =
    { flakelight, flakelight-lean, ... }:
    flakelight ./. {
      imports = [ flakelight-lean.flakelightModules.default ];

      # NB: The lakefile's [[lean_exe]] is named "minimal", which differs
      # casewise from the lakefile package name of "Minimal". This is an example
      # of how flakelight-lean can't infer this on its own and how calling users
      # of this module should specify the target name. Otherwise optional as per
      # docs.
      lean.target = "minimal";

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    };
}
