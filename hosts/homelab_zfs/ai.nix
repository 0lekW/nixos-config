# CPU-only local LLM host. Serves Ollama to Open WebUI and Lupin on homelab.
{ pkgs, ... }:

let
  model = "qwen3.8:27b";
in
{
  virtualisation.oci-containers.containers.ollama = {
    image = "ollama/ollama:0.40.15@sha256:a717bfc1c56acfc2e85d3109bd40a7646258ec9062c40cea83b9ed0927eb4223";
    ports = [ "11434:11434" ];
    volumes = [
      "/var/lib/ollama:/root/.ollama"
    ];
    environment = {
      # Keep the model resident; cold reloads are ~30s on CPU.
      OLLAMA_KEEP_ALIVE = "24h";
      # One request at a time: each slot gets its own KV cache.
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      # Smaller KV cache so bigger contexts fit in 32GB RAM.
      OLLAMA_FLASH_ATTENTION = "1";
      # Default context when a client doesn't specify num_ctx.
      OLLAMA_CONTEXT_LENGTH = "8192";
    };
    autoStart = true;
  };

  # Pull the model once the container's HTTP API is up; idempotent.
  systemd.services.ollama-model-pull = {
    description = "Ensure Ollama has ${model} downloaded";
    after = [ "docker-ollama.service" ];
    wants = [ "docker-ollama.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.curl ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Image pull on first run plus the model pull can take a while.
      TimeoutStartSec = "3h";
    };
    script = ''
      set -euo pipefail

      # Wait up to 20 min for the API: first-run image pull can be slow.
      for _ in $(seq 600); do
        curl -sf -m 3 http://localhost:11434/api/tags >/dev/null && break
        sleep 2
      done

      if ! curl -sf -m 3 http://localhost:11434/api/tags >/dev/null; then
        echo "Ollama API never became reachable at localhost:11434" >&2
        exit 1
      fi

      if curl -s http://localhost:11434/api/tags | grep -q '"name":"${model}"'; then
        echo "${model} already present"
        exit 0
      fi

      echo "Pulling ${model}..."
      curl -sf -X POST http://localhost:11434/api/pull \
        --data '{"name":"${model}","stream":false}' \
        -o /dev/null
      echo "Pull complete"
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/ollama 0755 olek docker - -"
  ];

  networking.firewall.allowedTCPPorts = [
    11434
  ];
}
