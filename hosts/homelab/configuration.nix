{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ./monitoring
    ./media.nix
    ./ai.nix
    ./network.nix
    ./apps.nix
  ];

  networking.hostName = "nixos_homelab";
  networking.interfaces.enp4s0.ipv4.addresses = [
    {
      address = "192.168.1.200";
      prefixLength = 24;
    }
  ];

  # Motherboard sensor chip, so node-exporter can read temperatures.
  boot.kernelModules = [ "nct6775" ];

  # GTX 1060, used by Jellyfin for transcoding and by Ollama.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.nvidia-container-toolkit.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    lm_sensors
    nodejs
    kitty.terminfo
    unstable.claude-code
  ];

  # Lets unpackaged dynamic binaries run.
  programs.nix-ld.enable = true;

  # Each service module declares the secrets it needs.
  sops = {
    defaultSopsFile = ../../secrets/homelab.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # Shared bridge that every container joins.
  systemd.services.create-homelab-network = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.docker}/bin/docker network ls | grep homelab || ${pkgs.docker}/bin/docker network create homelab
    '';
  };

  virtualisation.oci-containers.backend = "docker";

  system.stateVersion = "25.05";
}
