# Local LLM hosting: model server, web UI, and the task scheduler on top.
{ ... }:

{
  virtualisation.oci-containers.containers = {
      ollama = {
        image = "ollama/ollama@sha256:5a5d014aa774f78ebe1340c0d4afc2e35afc12a2c3b34c84e71f78ea20af4ba3";
        ports = [ "11434:11434" ];
        volumes = [
          "/var/lib/ollama:/root/.ollama"
        ];
        environment = {
          NVIDIA_VISIBLE_DEVICES = "all";
          NVIDIA_DRIVER_CAPABILITIES = "compute,utility";
        };
        autoStart = true;
        extraOptions = [
          "--network=homelab"
          "--device=nvidia.com/gpu=all"
        ];
      };

      open-webui = {
        image = "ghcr.io/open-webui/open-webui:main@sha256:b80a96e14bb15ea79aec96fbdad4aeab6b3ee7b61520d83b5dbc8c4f47d433a9";
        ports = [ "3001:8080" ]; # avoid clash with grafana on 3000
        volumes = [
          "/var/lib/open-webui:/app/backend/data"
        ];
        environment = {
          OLLAMA_BASE_URL = "http://ollama:11434";
        };
        dependsOn = [ "ollama" ];
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
        dependsOn = [ "ollama" ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

  };

  systemd.tmpfiles.rules = [
    "d /var/lib/ollama 0755 olek docker - -"
    "d /var/lib/open-webui 0755 olek docker - -"
    "d /var/lib/lupin 0755 olek docker - -"
  ];

  networking.firewall.allowedTCPPorts = [
    3001 # Open WebUI
    9500 # Lupin
    11434 # Ollama API
  ];
}
