{ fetchFromGitHub }:
let
  owner = "IgneousRed";
  repo = "odin-lint";
  version = "0.7.7";
  rev = "6cca8868fa34b8ddd291e358ae640571a60c80e4";
  hash = "sha256-dkWpSLZFDXKOEcpzyBLoM8RLJNNkzILF0tPwJRvVzEA=";
in
{
  inherit owner repo version rev hash;
  src = fetchFromGitHub { inherit owner repo rev hash; };
}
