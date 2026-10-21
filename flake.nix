{
  description = "Dayz Wallpapers — categorias e agendamento para DankMaterialShell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in {
      packages = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          plugin = pkgs.runCommand "dayz-wallpapers-plugin-1.0.0" { } ''
            mkdir -p $out
            cp -r ${./plugin}/. $out/
            chmod -R u+w $out
            substituteInPlace $out/DayzWallpapers.qml \
              --replace-fail '"python3"' '"${pkgs.python3}/bin/python3"'
          '';
        in {
          inherit plugin;
          default = pkgs.writeShellApplication {
            name = "dayz-wallpapers-install";
            runtimeInputs = [ pkgs.python3 pkgs.nix ];
            text = ''
              exec python3 ${./scripts/install.py} --source ${plugin} "$@"
            '';
          };
        });
      apps = eachSystem (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/dayz-wallpapers-install";
        };
      });
      nixosModules.default = { pkgs, ... }: {
        programs.dms-shell.plugins.DayzWallpapers.src = self.packages.${pkgs.stdenv.hostPlatform.system}.plugin;
      };
      homeManagerModules.default = { pkgs, ... }: {
        xdg.configFile."DankMaterialShell/plugins/DayzWallpapers".source = self.packages.${pkgs.stdenv.hostPlatform.system}.plugin;
      };
    };
}
