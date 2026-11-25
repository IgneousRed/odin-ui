{ fetchFromGitHub }:
let
  owner = "IgneousRed";
  repo = "odin-fuzz";
  version = "0.4.0";
  rev = "8e5e8e480a93b3eaa611c8e131341e4edf56c690";
  hash = "sha256-vQxfCMZPnvDv0yirVbO0no2YsIhXIngXv5Up+RgK4SA=";
in
{
  inherit owner repo version rev hash;
  src = fetchFromGitHub { inherit owner repo rev hash; };
}
