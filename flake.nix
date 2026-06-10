{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-webext.url = "github:rivavolt/nix-webext";
  };

  outputs =
    { self, nixpkgs, nix-webext }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      overlays.default = final: prev:
        let mkFF2mpv = pkgs: import ./package.nix { inherit pkgs nix-webext; src = self; };
        # The overlay attr is the installable derivation (`.default`); the full
        # nix-webext result (with extId/chromeContent passthrus) is on `packages`.
        in { ff2mpv = (mkFF2mpv final).default; };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        import ./package.nix { inherit pkgs nix-webext; src = self; }
      );
    };
}
