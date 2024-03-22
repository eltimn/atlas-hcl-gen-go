{
  description = "atlas-hcl-gen-go";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, gomod2nix, gitignore }:
    let
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs allSystems (system:
          f {
            inherit system;
            pkgs = import nixpkgs { inherit system; };
          });
    in {
      packages = forAllSystems ({ system, pkgs, ... }:
        let
          buildGoApplication =
            gomod2nix.legacyPackages.${system}.buildGoApplication;
        in rec {
          default = atlas-hcl-gen-go;

          atlas-hcl-gen-go = buildGoApplication {
            name = "atlas-hcl-gen-go";
            src = gitignore.lib.gitignoreSource ./.;
            go = pkgs.go_1_21;
            # Must be added due to bug https://github.com/nix-community/gomod2nix/issues/120
            pwd = ./.;
            # subPackages = [ "cmd/atlas-hcl-gen-go" ];
            CGO_ENABLED = 0;
            flags = [ "-trimpath" ];
            ldflags = [ "-s" "-w" "-extldflags -static" ];

            buildPhase = ''
              runHook preBuild
              echo "Building go binary ..."
              go build -o atlas-hcl-gen-go
              runHook postBuild
            '';

            postBuild = ''
              echo "Running go test ..."
              go test ./...
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp atlas-hcl-gen-go $out/bin/atlas-hcl-gen-go
              runHook postInstall
            '';
          };
        });

      # `nix develop` provides a shell containing development tools.
      devShell = forAllSystems ({ system, pkgs }:
        pkgs.mkShell {
          buildInputs = with pkgs; [
            (golangci-lint.override { buildGoModule = buildGo121Module; })
            go_1_21
            gopls
            goreleaser
            gomod2nix.legacyPackages.${system}.gomod2nix
          ];
        });
    };
}
