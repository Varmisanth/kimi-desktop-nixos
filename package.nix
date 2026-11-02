{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  p7zip,
  asar,
  makeDesktopItem,
  nodejs_24,
  python312,
  uv,
  electron,
  cacert,
  coreutils,
  curl,
  findutils,
  git,
  gnugrep,
  gnused,
  google-chrome,
  makeWrapper,
}:
let
  params = import ./params.nix;
  electronDist = electron.unwrapped + /libexec/electron;
  certFile = cacert + /etc/ssl/certs/ca-bundle.crt;
  libstdcpp = lib.makeLibraryPath [ stdenv.cc.cc.lib ];
  shimPath = lib.makeBinPath [
    coreutils
    findutils
    git
    gnugrep
    gnused
  ];
  desktopItem = makeDesktopItem {
    categories = [
      "Office"
      "Utility"
    ];
    desktopName = "Kimi Desktop";
    exec = "kimi-desktop";
    name = "kimi-desktop";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kimi-desktop";
  inherit (params.desktop) version;
  src = fetchurl {
    url = "https://kimi-img.moonshot.cn/app/download/windows/kimi_${finalAttrs.version}.exe";
    inherit (params.desktop) hash;
  };
  webbridgeSrc = fetchurl {
    url = "https://cdn.kimi.com/webbridge/v${params.webbridge.version}/releases/kimi-webbridge-linux-amd64";
    inherit (params.webbridge) hash;
  };
  nativeBuildInputs = [
    p7zip
    asar
    makeWrapper
    nodejs_24
    python312
    uv
  ];
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    export HOME=$TMPDIR
    mkdir -p $TMPDIR/nsis $TMPDIR/app64
    7z x -y -o$TMPDIR/nsis "$src" > /dev/null
    7z x -y -o$TMPDIR/app64 "$TMPDIR/nsis/\$PLUGINSDIR/app-64.7z" > /dev/null
    mkdir -p $out/share/kimi-desktop $out/bin $out/share/applications
    install -Dm755 $webbridgeSrc $out/share/kimi-desktop/app/resources/targets/linux-x64/kimi-webbridge
    asar extract $TMPDIR/app64/resources/app.asar $out/share/kimi-desktop/app
    rm -rf $out/share/kimi-desktop/app/out/native
    mkdir -p $TMPDIR/daimon
    tar xzf $TMPDIR/app64/resources/resources/daimon-bundle.tar.gz -C $TMPDIR/daimon
    mv $TMPDIR/daimon $out/share/kimi-desktop/daimon
    pushd $out/share/kimi-desktop/daimon > /dev/null
    rm -rf runtime
    find . -type f \( -name '*.exe' -o -name '*.dll' -o -name '*.cmd' -o -name '*.ps1' \) -delete
    popd > /dev/null
    cp ${./tools/daimon-shim.sh} $out/share/kimi-desktop/daimon/bin/daimon
    cp ${./tools/daimon-shim.sh} $out/share/kimi-desktop/daimon/bin/kimi-daimon
    for shim in daimon kimi-daimon; do
      substituteInPlace $out/share/kimi-desktop/daimon/bin/$shim \
        --replace-fail '@NODE@' '${lib.getExe nodejs_24}' \
        --replace-fail '@UV@' '${lib.getExe uv}' \
        --replace-fail '@PYTHON@' '${lib.getExe python312}' \
        --replace-fail '@SHIM_PATH@' '${shimPath}' \
        --replace-fail '@CERT_FILE@' '${certFile}' \
        --replace-fail '@LIBSTDCPP@' '${libstdcpp}'
      chmod 755 $out/share/kimi-desktop/daimon/bin/$shim
    done
    mkdir -p $out/share/kimi-desktop/app/resources/targets/linux-x64/runtime
    ln -s ../../../../daimon $out/share/kimi-desktop/app/resources/targets/linux-x64/daimon-bundle
    ln -s ${lib.getExe nodejs_24} $out/share/kimi-desktop/app/resources/targets/linux-x64/runtime/node
    cp -r $TMPDIR/app64/resources/resources/webbridge-extension $out/share/kimi-desktop/resources-webbridge-extension
    cp ${./tools/kimi-desktop-launcher.sh} $out/bin/kimi-desktop
    substituteInPlace $out/bin/kimi-desktop \
      --replace-fail '@OUT@' "$out" \
      --replace-fail '@ELECTRON_DIST@' '${electronDist}' \
      --replace-fail '@NODE@' '${lib.getExe nodejs_24}' \
      --replace-fail '@STAMP@' '${finalAttrs.version}-electron-${electron.version}' \
      --replace-fail '@CERT_FILE@' '${certFile}' \
      --replace-fail '@LIBSTDCPP@' '${libstdcpp}'
    chmod 755 $out/bin/kimi-desktop
    wrapProgram $out/bin/kimi-desktop --prefix PATH : ${lib.makeBinPath [ coreutils ]}
    cp ${./tools/kimi-webbridge-chrome.sh} $out/bin/kimi-webbridge-chrome
    substituteInPlace $out/bin/kimi-webbridge-chrome \
      --replace-fail '@CHROME@' '${lib.getExe google-chrome}' \
      --replace-fail '@CURL@' '${lib.getExe curl}' \
      --replace-fail '@SLEEP@' '${lib.getExe' coreutils "sleep"}' \
      --replace-fail '@WEBBRIDGE@' "$out/share/kimi-desktop/app/resources/targets/linux-x64/kimi-webbridge"
    chmod 755 $out/bin/kimi-webbridge-chrome
    cp ${desktopItem}/share/applications/kimi-desktop.desktop $out/share/applications/
    substituteInPlace $out/share/applications/kimi-desktop.desktop \
      --replace-fail 'Exec=kimi-desktop' "Exec=$out/bin/kimi-desktop"
    runHook postInstall
  '';
  meta = {
    description = "Kimi Desktop packaged for NixOS";
    homepage = "https://www.kimi.com/";
    license = lib.licenses.unfree;
    maintainers = [ (import ./maintainers.nix).varmisanth ];
    mainProgram = "kimi-desktop";
    platforms = lib.platforms.linux;
  };
})
