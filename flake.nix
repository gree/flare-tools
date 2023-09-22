{
  description = "flare-tools";
  nixConfig = {
    bash-prompt = "\\[\\033[1m\\][dev-flare-tools]\\[\\033\[m\\]\\040\\w$\\040";
  };
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs {
            inherit system;
          };
          env = with pkgs;
            bundlerEnv {
              name = "flare-tools";
              gemdir = ./.;
              gemConfig = defaultGemConfig // {
                tokyocabinet = attrs :{
                  buildInputs = [tokyocabinet zlib bzip2];
                };
              };
            };
     in
        rec {
          packages = flake-utils.lib.flattenTree {
            flare-tools = with pkgs; pkgs.stdenv.mkDerivation {
              name = "flare-tools";
              src = ./.;
              buildInputs = [ env ruby ];
              phases = [ "unpackPhase" "installPhase" ];
              installPhase = ''
                patchShebangs .
                mkdir -p $out/
                cp -r lib $out/
                cp -r bin $out/
              '';
            };
          };
          defaultPackage = packages.flare-tools;
          devShell = pkgs.mkShell {
            packages = with pkgs; [ ruby bundix env ];
            shellHook = ''
            '';
            inputsFrom = builtins.attrValues self.packages.${system};
          };
        }
    );
}
