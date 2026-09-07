# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/common.nix
    ./monitoring
    ./media.nix
    ./ai.nix
    ./network.nix
    ./apps.nix
  ];

  boot.kernelModules = [ "nct6775" ];

  networking.hostName = "nixos_homelab"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable NVIDIA drivers
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # For 32-bit applications if needed
  };

  # NVIDIA-specific settings
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false; # Proprietary driver
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Enable NVIDIA Container Toolkit for Docker
  hardware.nvidia-container-toolkit.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git
    lm_sensors
    nodejs
    kitty.terminfo
    unstable.claude-code
  ];

  programs.nix-ld.enable = true;

  # Encrypted secrets, committed to the repo in secrets/homelab.yaml.
  # The host unlocks them at boot using the private half of its SSH host key,
  # so a rebuild from scratch needs nothing typed in by hand.
  sops = {
    defaultSopsFile = ../../secrets/homelab.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  networking.interfaces.enp4s0.ipv4.addresses = [
    {
      address = "192.168.1.200";
      prefixLength = 24;
    }
  ];


  # Create the network for docker containers
  systemd.services.create-homelab-network = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.docker}/bin/docker network ls | grep homelab || ${pkgs.docker}/bin/docker network create homelab
    '';
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {

      # dashboard = {
      #   image = "0iek/homelab-dashboard:latest";
      #   ports = [ "8080:8080" ];
      #   volumes = [
      #     "/var/lib/dashboard/index.html:/usr/share/nginx/html/index.html:ro"
      #   ];
      #   autoStart = true;
      #   autoRemoveOnStop = false;
      #   extraOptions = [
      #     "--restart=always"
      #     "--network=homelab"
      #   ];
      # };

    };
  };

  systemd.tmpfiles.rules = [












  ];

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    8001
  ]; # check docker for port allocations...
  networking.firewall.allowedUDPPorts = [
  ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
