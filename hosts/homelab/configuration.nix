# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelModules = [ "nct6775" ];

  networking.hostName = "nixos_homelab"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

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
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    packages = with pkgs; [ ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
      pihole_env = { };
      vikunja_env = { };
      tailscale_env = { };
      closet_env = { };
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
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # fail2ban for some ssh protection
  services.fail2ban.enable = true;

  # Static IP setup
  networking.useDHCP = false;
  networking.interfaces.enp4s0.ipv4.addresses = [
    {
      address = "192.168.1.200";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = "192.168.1.254";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # Required so the tailscale container can act as a subnet router
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  # Create the network for docker containers
  systemd.services.create-homelab-network = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.docker}/bin/docker network ls | grep homelab || ${pkgs.docker}/bin/docker network create homelab
    '';
  };

  # Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
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

      glance = {
        image = "glanceapp/glance@sha256:6df86a7e8868d1eda21f35205134b1962c422957e42a0c44d4717c8e8f741b1a";
        ports = [ "8080:8080" ];
        volumes = [
          "/home/olek/nixos-config/hosts/homelab/glance/config:/app/config"
          "/home/olek/nixos-config/hosts/homelab/glance/assets:/app/assets"
        ];
        environment = {
          TZ = "Pacific/Auckland";
        };
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      rustdesk-hbbs = {
        image = "rustdesk/rustdesk-server:1.1.14@sha256:680f8ba5accafc264d15076f33a6fdb9cb6f4d963a0fc92e01023ca0e919cc83";
        cmd = [ "hbbs" ];
        volumes = [
          "/var/lib/rustdesk:/root"
        ];
        ports = [
          "21115:21115" # TCP, Rendezvous
          "21116:21116" # TCP, Relay (not used on LAN, but required by clients)
          "21116:21116/udp" # UDP Relay
          "21118:21118" # TCP, API/Web console
        ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      rustdesk-hbbr = {
        image = "rustdesk/rustdesk-server:1.1.14@sha256:680f8ba5accafc264d15076f33a6fdb9cb6f4d963a0fc92e01023ca0e919cc83";
        cmd = [ "hbbr" ];
        volumes = [
          "/var/lib/rustdesk:/root"
        ];
        ports = [
          "21117:21117" # TCP, Relay main
          "21119:21119" # TCP, Secondary relay
        ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      pihole = {
        image = "pihole/pihole:2025.08.0@sha256:90a1412b3d3037d1c22131402bde19180d898255b584d685c84d943cf9c14821";
        ports = [
          "53:53/tcp" # DNS TCP
          "53:53/udp" # DNS UDP
          "8082:8082/tcp" # Web interface
        ];
        environmentFiles = [ config.sops.secrets.pihole_env.path ];
        environment = {
          TZ = "Pacific/Auckland";
          FTLCONF_webserver_api_max_sessions = "50";
          FTLCONF_webserver_api_session_timeout = "300";
          FTLCONF_dns_listeningMode = "all";
          FTLCONF_webserver_port = "8082";
        };
        volumes = [
          "/var/lib/pihole/etc-pihole:/etc/pihole"
        ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent:5.1.2-r2-ls415@sha256:ffa4e82aa55e3bd3d2d99151f235fcd41b976303c4d4029940363452a59a3833";
        environment = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Pacific/Auckland";
          WEBUI_PORT = "8081";
          TORRENTING_PORT = "6881";
        };
        volumes = [
          "/var/lib/qbittorrent/config:/config"
          "/srv/torrents:/downloads"
        ];
        ports = [
          "8081:8081" # Web UI
          "6881:6881" # BitTorrent TCP
          "6881:6881/udp" # BitTorrent UDP
        ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      jellyfin = {
        image = "jellyfin/jellyfin:10.11.8@sha256:1694ff069f0c9dafb283c36765175606866769f5d72f2ed56b6a0f1be922fc37";
        environment = {
          TZ = "Pacific/Auckland";
          NVIDIA_VISIBLE_DEVICES = "all";
          NVIDIA_DRIVER_CAPABILITIES = "all";
        };
        volumes = [
          "/var/lib/jellyfin/config:/config" # configuration, users, metadata
          "/srv/torrents:/media/torrents" # point Jellyfin at torrent download dir
        ];
        ports = [
          "8096:8096" # Web UI / API (HTTP)
          # "8920:8920" # HTTPS (optional, if you add certs later)
        ];
        autoStart = true;
        extraOptions = [
          "--network=homelab"
          "--device=nvidia.com/gpu=all"
        ];
      };

      filebrowser = {
        image = "filebrowser/filebrowser@sha256:1d0bcba4bd7d8886cc6f77c791694d69f9c7c78e889c4ed3a5734529daed9fa1";
        volumes = [
          "/var/lib/filebrowser:/database" # filebrowser.db + settings
          "/srv:/srv" # browse your files under /srv
        ];
        ports = [ "8090:80" ]; # Web UI at http://192.168.1.200:8090
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      nodeexporter = {
        image = "prom/node-exporter@sha256:d00a542e409ee618a4edc67da14dd48c5da66726bbd5537ab2af9c1dfc442c8a";
        ports = [ "9100:9100" ];
        volumes = [
          "/proc:/host/proc:ro"
          "/sys:/host/sys:ro"
          "/sys/class/hwmon:/host/sys/class/hwmon:ro"
        ];
        cmd = [
          "--path.procfs=/host/proc"
          "--path.sysfs=/host/sys"
          "--collector.hwmon"
        ];
        extraOptions = [ "--network=homelab" ];
        autoStart = true;
      };

      prometheus = {
        image = "prom/prometheus@sha256:63805ebb8d2b3920190daf1cb14a60871b16fd38bed42b857a3182bc621f4996";
        ports = [ "9090:9090" ];
        volumes = [
          "/var/lib/prometheus:/prometheus"
          "${./monitoring/prometheus.yml}:/etc/prometheus/prometheus.yml:ro"
        ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      cadvisor = {
        image = "gcr.io/cadvisor/cadvisor@sha256:3cde6faf0791ebf7b41d6f8ae7145466fed712ea6f252c935294d2608b1af388";
        volumes = [
          "/:/rootfs:ro"
          "/var/run:/var/run:ro"
          "/sys:/sys:ro"
          "/var/lib/docker/:/var/lib/docker:ro"
        ];
        extraOptions = [
          "--privileged"
          "--network=homelab"
        ];
        autoStart = true;
      };

      grafana = {
        image = "grafana/grafana@sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d";
        ports = [ "3000:3000" ];
        volumes = [
          "/var/lib/grafana:/var/lib/grafana"
          "${./monitoring/grafana/provisioning}:/etc/grafana/provisioning:ro"
          "${./monitoring/grafana/dashboards}:/etc/grafana/dashboards:ro"
        ];
        environment = {
          TZ = "Pacific/Auckland";
          GF_SECURITY_ALLOW_EMBEDDING = "true";
          GF_AUTH_ANONYMOUS_ENABLED = "true";
          GF_AUTH_ANONYMOUS_ORG_ROLE = "Viewer";
        };
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      nginx-proxy-manager = {
        image = "jc21/nginx-proxy-manager@sha256:6ab097814f54b1362d5fd3c5884a01ddd5878aaae9992ffd218439180f0f92f3";
        ports = [
          "80:80" # HTTP
          "443:443" # HTTPS
          "81:81" # Admin interface
        ];
        volumes = [
          "/var/lib/nginx-proxy-manager/data:/data"
          "/var/lib/nginx-proxy-manager/letsencrypt:/etc/letsencrypt"
        ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      crafty-controller = {
        image = "registry.gitlab.com/crafty-controller/crafty-4:4.10.7@sha256:67c2cbab1c88b75efb41b2970b1faca1a736b3532f6d1a806a7fe3f81664a199";
        ports = [
          "8000:8443"
          "25565:25565"
        ]; # 8000 = web UI (local only), 25565 = Minecraft
        volumes = [
          "/srv/minecraft/backups:/crafty/backups"
          "/srv/minecraft/logs:/crafty/logs"
          "/srv/minecraft/servers:/crafty/servers"
          "/srv/minecraft/config:/crafty/app/config"
        ];
        environment = {
          TZ = "Pacific/Auckland";
        };
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      cjsonfmt-ui = {
        image = "0iek/cjsonfmt-ui@sha256:c862c5894869c3153ddd9a41198a7317f6ef19b13684288a548f64af3b4409f0";
        ports = [ "8761:8761" ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      oleks-closet = {
        image = "0iek/oleks-closet@sha256:a3cf095585fe9bdd633ecf3cea7dbb490bde66b3b82c88e4ff48b23dcc8f3ee5";
        ports = [ "8762:8762" ];
        environmentFiles = [ config.sops.secrets.closet_env.path ];
        volumes = [
          "/var/lib/oleks-closet/data:/app/data"
          "/var/lib/oleks-closet/uploads:/app/app/static/uploads"
        ];
        environment = {
          SQLALCHEMY_DATABASE_URI = "sqlite:////app/data/closet.db";
        };
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

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

      vikunja = {
        image = "vikunja/vikunja:2.3.0@sha256:f6b80393c1998cd5cd0dc38d24762c59ab4c10000a6f1032ef5b554e262cab93";
        ports = [ "8763:3456" ];
        volumes = [
          "/var/lib/vikunja:/app/vikunja/files"
        ];
        environment = {
          TZ = "Pacific/Auckland";
          VIKUNJA_DATABASE_TYPE = "sqlite";
          VIKUNJA_DATABASE_PATH = "/app/vikunja/files/vikunja.db";
          VIKUNJA_SERVICE_PUBLICURL = "http://192.168.1.200:8763";
        };
        environmentFiles = [ config.sops.secrets.vikunja_env.path ];
        autoStart = true;
        extraOptions = [ "--network=homelab" ];
      };

      tailscale = {
        image = "tailscale/tailscale@sha256:f15d5d3f4a68773a853180b72496f70ba614b64de0878c43fe3da39fe0afba47";
        volumes = [
          "/var/lib/tailscale:/var/lib/tailscale"
          "/dev/net/tun:/dev/net/tun"
        ];
        environment = {
          TS_STATE_DIR = "/var/lib/tailscale";
          TS_HOSTNAME = "homelab";
          TS_USERSPACE = "false";
          TS_ACCEPT_DNS = "false";
        };
        environmentFiles = [ config.sops.secrets.tailscale_env.path ];
        extraOptions = [
          "--network=host"
          "--cap-add=NET_ADMIN"
          "--cap-add=SYS_MODULE"
        ];
        autoStart = true;
      };

    };
  };

  systemd.tmpfiles.rules = [
    # qBittorrent
    "d /var/lib/qbittorrent 0755 olek docker - -"
    "d /var/lib/qbittorrent/config 0755 olek docker - -"
    "d /srv/torrents 0775 olek docker - -"

    # Jellyfin
    "d /var/lib/jellyfin 0755 olek docker - -"
    "d /var/lib/jellyfin/config 0755 olek docker - -"

    # RustDesk
    "d /var/lib/rustdesk 0755 olek docker - -"

    # Pi-hole
    "d /var/lib/pihole 0755 olek docker - -"
    "d /var/lib/pihole/etc-pihole 0755 olek docker - -"

    # File browser
    "d /var/lib/filebrowser 0755 olek docker - -"

    # System monitoring
    "d /var/lib/prometheus 0770 65534 65534 - -"
    "d /var/lib/grafana 0755 472 472 - -"

    # Nginx Proxy Manager
    "d /var/lib/nginx-proxy-manager 0755 olek docker - -"
    "d /var/lib/nginx-proxy-manager/data 0755 olek docker - -"
    "d /var/lib/nginx-proxy-manager/letsencrypt 0755 olek docker - -"

    # Minecraft server
    "d /srv/minecraft 0755 olek docker - -"
    "d /srv/minecraft/backups 0755 olek docker - -"
    "d /srv/minecraft/logs 0755 olek docker - -"
    "d /srv/minecraft/servers 0755 olek docker - -"
    "d /srv/minecraft/config 0755 olek docker - -"

    # Oleks closet
    "d /var/lib/oleks-closet 0755 olek docker - -"
    "d /var/lib/oleks-closet/data 0755 olek docker - -"
    "d /var/lib/oleks-closet/uploads 0755 olek docker - -"

    # Ollama + Open-WebUI
    "d /var/lib/ollama 0755 olek docker - -"
    "d /var/lib/open-webui 0755 olek docker - -"

    # Lupin
    "d /var/lib/lupin 0755 olek docker - -"

    # Vikunja
    "d /var/lib/vikunja 0755 olek docker - -"

    # Tailscale
    "d /var/lib/tailscale 0700 root root - -"
  ];

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    53
    80
    443
    3000
    3001
    6881
    8000
    8001
    8080
    8081
    8082
    8090
    8761
    8762
    8763
    9090
    9100
    9500
    11434
    21115
    21116
    21117
    21118
    21119
    25565
  ]; # check docker for port allocations...
  networking.firewall.allowedUDPPorts = [
    53
    6881
    21116
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
