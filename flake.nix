{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
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
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "ff2mpv";
            version = "0-unstable";

            src = self;

            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ pkgs.python3 ];

            installPhase = ''
              mkdir -p $out/bin \
                $out/lib/mozilla/native-messaging-hosts \
                $out/etc/chromium/native-messaging-hosts

              cp ff2mpv.py $out/bin/ff2mpv.py
              chmod +x $out/bin/ff2mpv.py
              patchShebangs $out/bin/ff2mpv.py

              substitute ff2mpv.json $out/lib/mozilla/native-messaging-hosts/ff2mpv.json \
                --replace-fail "/home/william/scripts/ff2mpv" "$out/bin/ff2mpv.py"

              substitute ff2mpv-chromium.json $out/etc/chromium/native-messaging-hosts/ff2mpv.json \
                --replace-fail "/home/william/scripts/ff2mpv" "$out/bin/ff2mpv.py"

              # Install browser extension source
              mkdir -p $out/share/chromium-extension
              cp manifest.json ff2mpv.js LICENSE $out/share/chromium-extension/
              cp -r icons options $out/share/chromium-extension/

              wrapProgram $out/bin/ff2mpv.py \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.mpv pkgs.streamlink pkgs.yt-dlp ]}
            '';

            meta = {
              description = "Native messaging host for ff2mpv browser extension";
              homepage = "https://github.com/woodruffw/ff2mpv";
              license = pkgs.lib.licenses.mit;
              mainProgram = "ff2mpv.py";
            };
          };
        }
      );
    };
}
