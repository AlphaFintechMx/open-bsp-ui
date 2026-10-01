{
  description = "Nix flake for OpenBSP UI";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  {
    nixosModules.default = import ./nix/module.nix;
    nixosModules.open-bsp-ui = import ./nix/module.nix;
    nixosModules.openbsp = import ./nix/module.nix;
  };
}
