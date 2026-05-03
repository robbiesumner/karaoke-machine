{
  description = "Karaoke Kiosk — NixOS appliance for UltraStar Deluxe";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      modules = [
        ./nix/modules/kiosk.nix
        ./nix/modules/audio.nix
        ./nix/modules/samba.nix
        ./nix/modules/firstboot.nix
        ./nix/modules/networking.nix
      ];
    in
    {
      nixosConfigurations.karaoke = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules ++ [ ./nix/system.nix ];
      };

      nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules ++ [
          ./nix/iso.nix
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ];
      };

      packages.${system}.iso =
        self.nixosConfigurations.iso.config.system.build.isoImage;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixpkgs-fmt
          nixos-rebuild
          git
        ];
      };

      formatter.${system} = pkgs.nixpkgs-fmt;
    };
}
