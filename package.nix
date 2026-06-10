{ pkgs, nix-webext, src }:
let
  extension = pkgs.stdenv.mkDerivation {
    pname = "ff2mpv";
    version = "0-unstable";

    inherit src;

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

      # cd into $HOME because Chromium chdirs to the host's /nix/store dir on launch and yt-dlp's tempfile handling fails there.
      wrapProgram $out/bin/ff2mpv.py \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.mpv pkgs.streamlink pkgs.yt-dlp ]} \
        --set-default https_proxy "http://127.0.0.1:1091" \
        --run 'cd "''${HOME:-/tmp}"'
    '';

    meta = {
      description = "Native messaging host for ff2mpv browser extension";
      homepage = "https://github.com/woodruffw/ff2mpv";
      license = pkgs.lib.licenses.mit;
      mainProgram = "ff2mpv.py";
    };
  };

  manifest = builtins.fromJSON (builtins.readFile (src + "/manifest.json"));
  geckoId = manifest.browser_specific_settings.gecko.id;
  extId = "fjlcpmdimhknioljkjpaaadbapolemki";

  # Chrome native-messaging host registration (the Firefox one ships in the
  # extension derivation at lib/mozilla/...). Points at this extension's stable
  # Chrome id.
  nativeMessaging = pkgs.linkFarm "ff2mpv-native" [
    { name = "etc/chromium/native-messaging-hosts/ff2mpv.json";
      path = pkgs.writeText "ff2mpv.json" (builtins.toJSON {
        name = "ff2mpv";
        description = "ff2mpv's external manifest";
        path = "${extension}/bin/ff2mpv.py";
        type = "stdio";
        allowed_origins = [ "chrome-extension://${extId}/" ];
      });
    }
  ];

  # Keyless build: Chrome CRX signed at activation from the sops key; extId is
  # the stable Chrome ID the old committed key derived. The manifest carries both
  # background forms, so the MV3 transform projects each browser's. extension is
  # folded in so its native-messaging host + bin land in `default`.
  ext = nix-webext.lib.mkBrowserExtension {
    inherit pkgs extension extId geckoId;
    pname = "ff2mpv";
    version = manifest.version;
    extraPaths = [ extension nativeMessaging ];
  };
in
# Return the whole nix-webext result: `default` (the symlinkJoin with the CRX
# manifest + Firefox XPI + native-messaging hosts) plus the extId/chromeContent
# passthrus nixos-config's activation signer needs.
ext
