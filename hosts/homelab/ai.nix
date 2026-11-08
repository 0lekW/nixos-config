# Local LLM frontends. Ollama itself runs on the zfs host (see
# hosts/homelab_zfs/ai.nix); Open WebUI and Lupin call it over the LAN.
{ ... }:

let
  ollamaUrl = "http://192.168.1.201:11434";
in
{
  virtualisation.oci-containers.containers = {
    open-webui = {
      image = "ghcr.io/open-webui/open-webui:main@sha256:b80a96e14bb15ea79aec96fbdad4aeab6b3ee7b61520d83b5dbc8c4f47d433a9";
      ports = [ "3001:8080" ]; # avoid clash with grafana on 3000
      volumes = [
        "/var/lib/open-webui:/app/backend/data"
      ];
      environment = {
        OLLAMA_BASE_URL = ollamaUrl;
      };
      autoStart = true;
      extraOptions = [ "--network=homelab" ];
    };

    lupin = {
      image = "0iek/lupin@sha256:590ce2007cf0e4c8611f224145dd1b48edde485e7d6a043be7bcf4b4af1ad4f7";
      ports = [ "9500:9500" ];
      volumes = [
        "/var/lib/lupin:/data"
      ];
      environment = {
        TZ = "Pacific/Auckland";
      };
      # Override the image's baked-in -ollama http://ollama:11434 flag,
      # which assumes ollama is a sibling container on the same bridge.
      cmd = [
        "-addr" ":9500"
        "-data" "/data"
        "-sdk" "/app/sdk"
        "-python" "python3"
        "-ollama" ollamaUrl
      ];
      autoStart = true;
      extraOptions = [ "--network=homelab" ];
    };

  };

  systemd.tmpfiles.rules = [
    "d /var/lib/open-webui 0755 olek docker - -"
    "d /var/lib/lupin 0755 olek docker - -"
  ];

  networking.firewall.allowedTCPPorts = [
    3001 # Open WebUI
    9500 # Lupin
  ];
}
