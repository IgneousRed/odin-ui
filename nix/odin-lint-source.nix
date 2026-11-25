{ fetchFromGitHub }:
let
  owner = "IgneousRed";
  repo = "odin-lint";
  version = "0.7.7";
  rev = "7f6d541b086bde8ab866a93dec024e11d8288fed";
  hash = "sha256-W0v8iy+CrnuQm5HEWEp8fdip6ECIpVp3+V+1mgxNJnk=";
in
{
  inherit owner repo version rev hash;
  src = fetchFromGitHub { inherit owner repo rev hash; };
}
