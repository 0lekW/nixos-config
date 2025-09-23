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

  boot.kernelModules = [ "nct6775" ];

  networking.hostName = "nixos_homelab"; # Define your hostname.
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
  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  git
  lm_sensors
  nodejs
  ];

  programs.nix-ld.enable = true;

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
  networking.interfaces.enp4s0.ipv4.addresses = [{
  	address = "192.168.1.200";
	prefixLength = 24;
  }];

  networking.defaultGateway = "192.168.1.254";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

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

	  dashy = {
            image = "lissy93/dashy:latest";
	    ports = [ "8080:8080" ];
	    volumes = [
	      "/var/lib/dashy/conf.yml:/app/user-data/conf.yml"
	    ];
	    autoStart = true;
            autoRemoveOnStop = false;
            extraOptions = [ "--restart=always" "--network=homelab" ];
   	  };

	  rustdesk-hbbs = {
      	    image = "rustdesk/rustdesk-server:latest";
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
      	    image = "rustdesk/rustdesk-server:latest";
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
	    image = "pihole/pihole:latest";
  	    ports = [
	      "53:53/tcp" # DNS TCP
	      "53:53/udp" # DNS UDP
	      "8082:8082/tcp" # Web interface
	    ];
	    environment = {
	      TZ = "Pacific/Auckland";
	      FTLCONF_webserver_api_password = "admin";
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
  	    image = "lscr.io/linuxserver/qbittorrent:latest";
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
    	      "8081:8081"         # Web UI
    	      "6881:6881"         # BitTorrent TCP
    	      "6881:6881/udp"     # BitTorrent UDP
  	    ];
  	    autoStart = true;
        extraOptions = [ "--network=homelab" ];
	  };

	  jellyfin = {
  	    image = "jellyfin/jellyfin:latest";
  	    environment = {
    	      TZ = "Pacific/Auckland";
  	    };
  	    volumes = [
    	      "/var/lib/jellyfin/config:/config"    # configuration, users, metadata
    	      "/srv/torrents:/media/torrents"       # point Jellyfin at torrent download dir
  	    ];
  	    ports = [
    	      "8096:8096"   # Web UI / API (HTTP)
    	      # "8920:8920" # HTTPS (optional, if you add certs later)
  	    ];
  	    autoStart = true;
        extraOptions = [ "--network=homelab" ];
	  };

	  filebrowser = {
  	    image = "filebrowser/filebrowser:latest";
  	    volumes = [
    	      "/var/lib/filebrowser:/database"   # filebrowser.db + settings
    	      "/srv:/srv"                        # browse your files under /srv
  	    ];
  	    ports = [ "8090:80" ];               # Web UI at http://192.168.1.200:8090
  	    autoStart = true;
        extraOptions = [ "--network=homelab" ];
	  };

	  ttyd = {
  	    image = "tsl0922/ttyd:latest";
  	    volumes = [
    	      "/srv:/srv" # access files in the terminal
  	    ];
  	    ports = [ "8091:7681" ]; # Web terminal at 8091
  	    cmd = [ "ttyd" "-W" "bash" "-c" "cd /srv && exec bash" ];
  	    autoStart = true;
        extraOptions = [ "--network=homelab" ];
	  };

    nodeexporter = {
      image = "prom/node-exporter:latest";
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
      extraOptions = [ "--privileged" "--network=homelab" ];
      autoStart = true;
    };

    prometheus = {
      image = "prom/prometheus:latest";
      ports = [ "9090:9090" ];
      volumes = [
        "/var/lib/prometheus:/prometheus"
        "/var/lib/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro"
      ];
      autoStart = true;
      extraOptions = [ "--network=homelab" ];
    };

    grafana = {
      image = "grafana/grafana:latest";
      ports = [ "3000:3000" ];
      volumes = [
        "/var/lib/grafana:/var/lib/grafana"
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
      image = "jc21/nginx-proxy-manager:latest";
      ports = [ 
        "80:80"     # HTTP
        "443:443"   # HTTPS  
        "81:81"     # Admin interface
      ];
      volumes = [
        "/var/lib/nginx-proxy-manager/data:/data"
        "/var/lib/nginx-proxy-manager/letsencrypt:/etc/letsencrypt"
      ];
      autoStart = true;
      extraOptions = [ "--network=homelab" ];
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

    # Dashy
    "d /var/lib/dashy 0755 olek docker - -"
    "f /var/lib/dashy/conf.yml 0664 olek docker - -"
    # If we store conf.yml in /var/lib/dashy/conf.yml as per config
    # it will exist after first start, but we still ensure directory exists

    # RustDesk
    "d /var/lib/rustdesk 0755 olek docker - -"

    # Pi-hole
    "d /var/lib/pihole 0755 olek docker - -"
    "d /var/lib/pihole/etc-pihole 0755 olek docker - -"

    # File browser
    "d /var/lib/filebrowser 0755 olek docker - -"

    # System monitoring
    "d /var/lib/prometheus 0770 65534 65534 - -"
    "f /var/lib/prometheus/prometheus.yml 0644 olek docker - -"
    "d /var/lib/grafana 0755 472 472 - -"

    # Nginx Proxy Manager
    "d /var/lib/nginx-proxy-manager 0755 olek docker - -"
    "d /var/lib/nginx-proxy-manager/data 0755 olek docker - -"
    "d /var/lib/nginx-proxy-manager/letsencrypt 0755 olek docker - -"
  ];


  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 53 80 443 3000 6881 8080 8081 8082 8090 8091 9090 9100 21115 21116 21117 21118 21119 ]; # check docker for port allocations...
  networking.firewall.allowedUDPPorts = [ 53 6881 21116 ];
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
