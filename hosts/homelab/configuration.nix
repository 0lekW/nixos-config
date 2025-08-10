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
  ];

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
            extraOptions = [ "--restart=always" ];
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
	      FTLCONF_dns_listeningMode = "all";
	      FTLCONF_webserver_port = "8082";
	    };
	    volumes = [
	      "/var/lib/pihole/etc-pihole:/etc/pihole"
	    ];
	    autoStart = true;
	  };

	};
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 53 8080 8082 21115 21116 21117 21118 21119 ]; # check docker for port allocations...
  networking.firewall.allowedUDPPorts = [ 53 21116 ];
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
