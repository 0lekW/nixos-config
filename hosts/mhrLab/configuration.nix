{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ./storage.nix
    ./network.nix
    ./monitoring
    ./media.nix
    ./photos.nix
    ./cameras.nix
    ./dashboard.nix
  ];

  networking.hostName = "mhrLab";
  networking.hostId = "0d22c46e"; # required by ZFS

  # Jozef's LAN, not Olek's: its own router and address range.
  networking.useDHCP = false;
  networking.interfaces.eno1.ipv4.addresses = [
    {
      address = "192.168.0.200";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "192.168.0.1";
  # Not Pi-hole itself, so the box still resolves while Pi-hole is down.
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # Password is set by hand with `passwd` (and `smbpasswd -a jozef` for Samba);
  # SSH is key-only.
  users.users.jozef = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = [
      # Olek's MacBook
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC99At+lExwH5lWMdrgM88SjInaUs0PH1WKaB93rK98x"
    ];
  };

  # i5-2400 iGPU (Sandy Bridge). Only the old i965 VA-API driver supports it,
  # and only for H.264. Jellyfin and Frigate get /dev/dri passed through.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-vaapi-driver ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "i965";

  # Coretemp, so node-exporter can read CPU temperatures.
  boot.kernelModules = [ "coretemp" ];

  environment.systemPackages = with pkgs; [
    vim
    git
    lm_sensors
    pciutils
    smartmontools
    libva-utils
    kitty.terminfo
  ];

  # Each service module declares the secrets it needs.
  sops = {
    defaultSopsFile = ../../secrets/mhrLab.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # Shared bridge that every container joins, so they reach each other by name.
  systemd.services.create-mhrlab-network = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.docker}/bin/docker network ls | grep mhrlab || ${pkgs.docker}/bin/docker network create mhrlab
    '';
  };

  virtualisation.oci-containers.backend = "docker";

  system.stateVersion = "26.05"; # installed from the 26.05 ISO
}
