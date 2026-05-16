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
          pkgs = import nixpkgs { inherit system; };
        in
        { default = import ./package.nix { inherit pkgs nix-crx; src = self; }; }
      );
    };
}
