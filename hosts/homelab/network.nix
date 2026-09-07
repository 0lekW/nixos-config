# DNS filtering, reverse proxy, VPN, remote desktop.
{ config, ... }:

{
  virtualisation.oci-containers.containers = {
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

  sops.secrets.pihole_env = { };
  sops.secrets.tailscale_env = { };

  # Required so the tailscale container can act as a subnet router.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  systemd.tmpfiles.rules = [
    "d /var/lib/rustdesk 0755 olek docker - -"
    "d /var/lib/pihole 0755 olek docker - -"
    "d /var/lib/pihole/etc-pihole 0755 olek docker - -"
    "d /var/lib/nginx-proxy-manager 0755 olek docker - -"
    "d /var/lib/nginx-proxy-manager/data 0755 olek docker - -"
    "d /var/lib/nginx-proxy-manager/letsencrypt 0755 olek docker - -"
    "d /var/lib/tailscale 0700 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [
    53 # Pi-hole DNS
    80 # proxy HTTP
    443 # proxy HTTPS
    8082 # Pi-hole admin
    21115
    21116
    21117
    21118
    21119 # RustDesk
  ];
  networking.firewall.allowedUDPPorts = [
    53 # Pi-hole DNS
    21116 # RustDesk
  ];
}
