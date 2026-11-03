{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    in {
      devShells.aarch64-darwin.default = pkgs.mkShell {
        packages          = [ pkgs.ruby_4_0 ];
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs       = [ pkgs.openssl pkgs.libyaml pkgs.zlib ];
      };
    };
}
