# DNS ad blocking for the house, and Tailscale so Olek can reach it remotely.
{ config, ... }:

{
  virtualisation.oci-containers.containers = {
    pihole = {
      image = "pihole/pihole:2025.08.0@sha256:90a1412b3d3037d1c22131402bde19180d898255b584d685c84d943cf9c14821";
      ports = [
        "53:53/tcp" # DNS TCP
        "53:53/udp" # DNS UDP
        "8082:8082/tcp" # Web interface
      ];
      # FTLCONF_webserver_api_password
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
      extraOptions = [ "--network=mhrlab" ];
    };

    # Joins Olek's tailnet and advertises this LAN, so every IP:port link
    # (and the cameras) works remotely once the route is approved in the
    # Tailscale admin console.
    tailscale = {
      image = "tailscale/tailscale@sha256:f15d5d3f4a68773a853180b72496f70ba614b64de0878c43fe3da39fe0afba47";
      volumes = [
        "/var/lib/tailscale:/var/lib/tailscale"
        "/dev/net/tun:/dev/net/tun"
      ];
      environment = {
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_HOSTNAME = "mhrlab";
        TS_USERSPACE = "false";
        TS_ACCEPT_DNS = "false";
        TS_ROUTES = "192.168.0.0/24";
      };
      # TS_AUTHKEY
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
    "d /var/lib/pihole 0755 root root - -"
    "d /var/lib/pihole/etc-pihole 0755 root root - -"
    "d /var/lib/tailscale 0700 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [
    53 # Pi-hole DNS
    8082 # Pi-hole admin
  ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}
