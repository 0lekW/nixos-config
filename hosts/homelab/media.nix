# Media: torrent client and the library that serves what it fetches.
{ ... }:

{
  virtualisation.oci-containers.containers = {
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

  };

  systemd.tmpfiles.rules = [
    "d /var/lib/qbittorrent 0755 olek docker - -"
    "d /var/lib/qbittorrent/config 0755 olek docker - -"
    "d /srv/torrents 0775 olek docker - -"
    "d /var/lib/jellyfin 0755 olek docker - -"
    "d /var/lib/jellyfin/config 0755 olek docker - -"
  ];

  # Jellyfin is reached through the proxy, so 8096 stays closed.
  networking.firewall.allowedTCPPorts = [
    8081 # qBittorrent web UI
    6881 # BitTorrent
  ];
  networking.firewall.allowedUDPPorts = [ 6881 ];
}
