# Glance home page, linking every service on this box. Config lives in
# ./glance and is copied into the Nix store, so a rebuild picks up edits.
{ ... }:

{
  virtualisation.oci-containers.containers.glance = {
    image = "glanceapp/glance@sha256:6df86a7e8868d1eda21f35205134b1962c422957e42a0c44d4717c8e8f741b1a";
    ports = [ "8080:8080" ];
    volumes = [ "${./glance}:/app/config:ro" ];
    environment.TZ = "Pacific/Auckland";
    autoStart = true;
    extraOptions = [ "--network=mhrlab" ];
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
