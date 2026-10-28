# A desktop on a server, and a new host with a copied address.
{ sven, ... }:
{
  sven.aspects.desktop.at = sven.host.web;
  sven.host.spare = { addr = "10.0.0.2"; form = "server"; };
}
