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
              (final: prev: {
                yt-dlp = prev.yt-dlp.override { javascriptSupport = false; };
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

          manifest = builtins.fromJSON (builtins.readFile ./manifest.json);
          geckoId = manifest.browser_specific_settings.gecko.id;


          crxPkg = nix-crx.lib.mkCrxPackage {
            inherit pkgs extension;
            key = ./keys/signing.pem;
            extId = "fjlcpmdimhknioljkjpaaadbapolemki";
            version = manifest.version;
          };

          extDir = "share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";

          firefoxXpi = pkgs.stdenv.mkDerivation {
            pname = "ff2mpv-firefox-xpi";
            version = manifest.version;
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.zip ];
            buildPhase = ''
              cd ${extension}/share/chromium-extension
              zip -r $TMPDIR/extension.xpi .
            '';
            installPhase = ''
              mkdir -p $out/${extDir}
              cp $TMPDIR/extension.xpi $out/${extDir}/${geckoId}.xpi
            '';
          };
        in
        {
          default = pkgs.symlinkJoin {
            name = "ff2mpv";
            paths = [
              extension
              crxPkg.package
              firefoxXpi
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
