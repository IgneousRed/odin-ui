{ fetchFromGitHub }:
let
  owner = "IgneousRed";
  repo = "odin-lint";
  version = "0.7.7";
  rev = "8643e84c9d56ed02ff3cfd75a3aad717447ae9d7";
  hash = "sha256-Z59eOhN903T4TbZ5703gH7svufjbdT7jY9WD2XD0OYc=";
in
{
  inherit owner repo version rev hash;
  src = fetchFromGitHub { inherit owner repo rev hash; };
}
