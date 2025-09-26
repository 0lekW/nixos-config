# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos_homelab2"; # Define your hostname.
  networking.hostId = "afd9d661";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set your time zone.
  time.timeZone = "Pacific/Auckland";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_NZ.UTF-8";
    LC_IDENTIFICATION = "en_NZ.UTF-8";
    LC_MEASUREMENT = "en_NZ.UTF-8";
    LC_MONETARY = "en_NZ.UTF-8";
    LC_NAME = "en_NZ.UTF-8";
    LC_NUMERIC = "en_NZ.UTF-8";
    LC_PAPER = "en_NZ.UTF-8";
    LC_TELEPHONE = "en_NZ.UTF-8";
    LC_TIME = "en_NZ.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "us";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.olek = {
    isNormalUser = true;
    description = "Alex Wardega";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  vim
  git
  lm_sensors
  perccli # for storage managment
  pciutils
  lsscsi
  smartmontools
  hdparm sg3_utils
  zfs
  ];

  # --- ZFS: enable and tune ---
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "tank" ];

  services.zfs = {
    autoScrub.enable = true;   # monthly scrub (integrity check)
  };

  # Declarative first-run creation of the pool:
  systemd.services."zpool-create-tank" = {
  description = "Create ZFS pool 'tank' (RAIDZ1 on sdb/sdc/sdd) if missing";
  wantedBy = [ "multi-user.target" ];
  after = [ "local-fs.target" "systemd-udev-settle.service" ];
  requires = [ "systemd-udev-settle.service" ];
  before = [ "zfs-import.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = pkgs.writeShellScript "create-zpool-tank" ''
      set -euo pipefail
      export PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin

      # If pool already exists, do nothing
      if zpool list -H tank >/dev/null 2>&1; then
        exit 0
      fi

      # Prefer stable by-path symlinks for sdb/sdc/sdd
      ids=()
      for x in b c d; do
        p="$(ls -1 /dev/disk/by-path/*-sd''${x} 2>/dev/null | head -n1 || true)"
        if [ -n "''${p}" ]; then
          ids+=("''${p}")
        else
          # fallback to plain /dev/sdX if by-path missing
          ids+=("/dev/sd''${x}")
        fi
      done

      # Create the pool (mounted at /tank), SSD-friendly, with compression
      zpool create -f \
        -o ashift=12 \
        -O compression=zstd \
        -O atime=off \
        -O xattr=sa \
        -O acltype=posixacl \
        -m /tank \
        tank raidz1 "''${ids[@]}"

      # Datasets
      zfs create tank/media
      zfs create tank/shared
    '';
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

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Static IP setup
  networking.useDHCP = false;
  networking.interfaces.eno8303.ipv4.addresses = [{
  	address = "192.168.1.201";
	prefixLength = 24;
  }];

  networking.defaultGateway = "192.168.1.254";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
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
