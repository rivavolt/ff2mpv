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
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              # Temporary: update yt-dlp to support --remote-components for YouTube n-challenge
              (final: prev: {
                yt-dlp = prev.yt-dlp.overrideAttrs (old: {
                  version = "2026.02.04";
                  src = prev.fetchFromGitHub {
                    owner = "yt-dlp";
                    repo = "yt-dlp";
                    rev = "2026.02.04";
                    hash = "sha256-KXnz/ocHBftenDUkCiFoBRBxi6yWt0fNuRX+vKFWDQw=";
                  };
                  postPatch = builtins.replaceStrings
                    [ "if curl_cffi_version != (0, 5, 10) and not (0, 10) <= curl_cffi_version < (0, 14)" ]
                    [ "if curl_cffi_version != (0, 5, 10) and not (0, 10) <= curl_cffi_version < (0, 15)" ]
                    old.postPatch;
                });
              })
            ];
          };

          extension = pkgs.stdenv.mkDerivation {
            pname = "ff2mpv";
            version = "0-unstable";

            src = self;

            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ pkgs.python3 ];

            installPhase = ''
              mkdir -p $out/bin \
                $out/lib/mozilla/native-messaging-hosts

              cp ff2mpv.py $out/bin/ff2mpv.py
              chmod +x $out/bin/ff2mpv.py
              patchShebangs $out/bin/ff2mpv.py

              substitute ff2mpv.json $out/lib/mozilla/native-messaging-hosts/ff2mpv.json \
                --replace-fail "/home/william/scripts/ff2mpv" "$out/bin/ff2mpv.py"

              # Install browser extension source
              mkdir -p $out/share/chromium-extension
              cp manifest.json ff2mpv.js LICENSE $out/share/chromium-extension/
              cp -r icons options $out/share/chromium-extension/

              # Only add streamlink and yt-dlp; mpv is inherited from system PATH
              # so the user's mpv-with-scripts (uosc, thumbfast, etc.) is used
              wrapProgram $out/bin/ff2mpv.py \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.streamlink pkgs.yt-dlp ]} \
                --set-default https_proxy "http://127.0.0.1:1091"
            '';

            meta = {
              description = "Native messaging host for ff2mpv browser extension";
              homepage = "https://github.com/woodruffw/ff2mpv";
              license = pkgs.lib.licenses.mit;
              mainProgram = "ff2mpv.py";
            };
          };

          crxPkg = nix-crx.lib.mkCrxPackage {
            inherit pkgs extension;
            key = ./keys/signing.pem;
          };
        in
        {
          default = pkgs.symlinkJoin {
            name = "ff2mpv";
            paths = [
              extension
              crxPkg.package
              (pkgs.linkFarm "ff2mpv-native" [
                { name = "etc/chromium/native-messaging-hosts/ff2mpv.json";
                  path = pkgs.writeText "ff2mpv.json" (builtins.toJSON {
                    name = "ff2mpv";
                    description = "ff2mpv's external manifest";
                    path = "${extension}/bin/ff2mpv.py";
                    type = "stdio";
                    allowed_origins = [ "chrome-extension://${crxPkg.extId}/" ];
                  });
                }
              ])
            ];
          };
        }
      );
    };
}
