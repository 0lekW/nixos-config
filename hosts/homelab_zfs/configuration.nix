# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/common.nix
  ];

  networking.hostName = "nixos_zfs_storage"; # Define your hostname.
  networking.hostId = "afd9d661";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    git
    lm_sensors
    kitty.terminfo
    perccli # for storage managment
    pciutils
    lsscsi
    smartmontools
    hdparm
    sg3_utils
    zfs
  ];

  # --- ZFS: enable and tune ---
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "tank" ];

  # Encrypted secrets, committed to the repo in secrets/homelab_zfs.yaml.
  # Unlocked at boot using the private half of this host's SSH key.
  sops = {
    defaultSopsFile = ../../secrets/homelab_zfs.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.immich_env = { };
  };

  services.zfs = {
    autoScrub.enable = true; # monthly scrub (integrity check)
  };

  # Declarative first-run creation of the pool:
  systemd.services."zpool-create-tank" = {
    description = "Create ZFS pool 'tank' (RAIDZ1 on sdb/sdc/sdd) if missing";
    wantedBy = [ "multi-user.target" ];
    after = [
      "local-fs.target"
      "systemd-udev-settle.service"
    ];
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

  systemd.tmpfiles.rules = [
    "d /tank/shared 0775 olek users -"
    "d /var/lib/filebrowser 0755 olek docker - -"

    "d /var/lib/immich 0750 root root - -"
    "d /var/lib/immich/model-cache 0750 root root - -"
    "d /var/lib/immich/postgres 0700 root root - -"
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  networking.interfaces.eno8303.ipv4.addresses = [
    {
      address = "192.168.1.201";
      prefixLength = 24;
    }
  ];

  # Samba for NFS
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "NixOS ZFS NAS";
        "security" = "user";
        "hosts allow" = "192.168.1.0/24";
        "map to guest" = "bad user";
      };

      "shared" = {
        "path" = "/tank/shared";
        "browseable" = "yes";
        "writable" = "yes";
        "guest ok" = "no";
        "valid users" = "olek";
        "force user" = "olek";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  systemd.services.create-immich-network = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.docker}/bin/docker network ls | grep immich || ${pkgs.docker}/bin/docker network create immich
    '';
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {

      filebrowser = {
        image = "filebrowser/filebrowser@sha256:f63369420687482dfdf252f80ef675f44ca1d1cd3a631261fb424136214fe629";
        ports = [ "8080:80" ];
        volumes = [
          "/var/lib/filebrowser:/database"
          "/tank/shared:/srv/shared"
        ];
        autoStart = true;
      };

      immich-server = {
        image = "ghcr.io/immich-app/immich-server:v2.7.5@sha256:c15bff75068effb03f4355997d03dc7e0fc58720c2b54ad6f7f10d1bc57efaa5";
        ports = [ "2283:2283" ];
        environmentFiles = [ config.sops.secrets.immich_env.path ];
        dependsOn = [ "immich-redis" "immich-postgres" ];
        environment = {
          DB_HOSTNAME = "immich-postgres";
          DB_USERNAME = "postgres";
          DB_DATABASE_NAME = "immich";
          REDIS_HOSTNAME = "immich-redis";
        };
        volumes = [ "/tank/shared/Olek/Photos/immich:/data" ];   # was /usr/src/app/upload
        autoStart = true;
        extraOptions = [ "--network=immich" ];
      };

      immich-machine-learning = {
        image = "ghcr.io/immich-app/immich-machine-learning:v2.7.5@sha256:a2501141440f10516d329fdfba2c68082e19eb9ba6016c061ac80d23beadf7f3";
        volumes = [ "/var/lib/immich/model-cache:/cache" ];
        autoStart = true;
        extraOptions = [ "--network=immich" ];
      };

      immich-redis = {
        image = "docker.io/valkey/valkey:9@sha256:4963247afc4cd33c7d3b2d2816b9f7f8eeebab148d29056c2ca4d7cbc966f2d9";                      # was valkey:8-bookworm
        autoStart = true;
        extraOptions = [ "--network=immich" ];
      };

      immich-postgres = {
        image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";  # tag had drifted
        environmentFiles = [ config.sops.secrets.immich_env.path ];
        environment = {
          POSTGRES_USER = "postgres";
          POSTGRES_DB = "immich";
        };
        volumes = [ "/var/lib/immich/postgres:/var/lib/postgresql/data" ];
        autoStart = true;
        extraOptions = [ "--network=immich" ];
      };

    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    22
    139
    445
    2283
    8080
  ];
  networking.firewall.allowedUDPPorts = [
    137
    138
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
