{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-crx.url = "github:andreivolt/nix-crx";
  };

  outputs =
    { self, nixpkgs, nix-crx }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      overlays.default = final: prev:
        let mkFF2mpv = pkgs: import ./package.nix { inherit pkgs nix-crx; src = self; };
        in { ff2mpv = mkFF2mpv final; };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                deno = prev.deno.overrideAttrs (old: {
                  CARGO_BUILD_JOBS = "4";
                  preBuild = (old.preBuild or "") + ''
                    export CARGO_PROFILE_RELEASE_LTO=false
                  '';
                });
              })
            ];
          };
        in
        { default = import ./package.nix { inherit pkgs nix-crx; src = self; }; }
      );
    };
}
