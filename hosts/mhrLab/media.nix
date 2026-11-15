# Torrenting, and the media server that plays what it fetches. Both live on
# tank/media.
{ ... }:

let
  # Don't start before the pool is mounted, or Docker bind-mounts an empty
  # directory on the SSD and downloads land there.
  needsTank = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    unitConfig.ConditionPathIsMountPoint = "/tank/media";
  };
in
{
  virtualisation.oci-containers.containers = {
    qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:5.1.2-r2-ls415@sha256:ffa4e82aa55e3bd3d2d99151f235fcd41b976303c4d4029940363452a59a3833";
      environment = {
        PUID = "1000"; # jozef
        PGID = "100"; # users
        TZ = "Pacific/Auckland";
        WEBUI_PORT = "8081";
        TORRENTING_PORT = "6881";
      };
      volumes = [
        "/var/lib/qbittorrent/config:/config"
        # Same path as in Jellyfin, so the movies/tv categories save straight
        # into the libraries.
        "/tank/media:/media"
      ];
      ports = [
        "8081:8081" # Web UI
        "6881:6881" # BitTorrent TCP
        "6881:6881/udp" # BitTorrent UDP
      ];
      autoStart = true;
      extraOptions = [ "--network=mhrlab" ];
    };

    jellyfin = {
      image = "jellyfin/jellyfin:10.11.8@sha256:1694ff069f0c9dafb283c36765175606866769f5d72f2ed56b6a0f1be922fc37";
      environment = {
        TZ = "Pacific/Auckland";
        # Sandy Bridge iGPU: pick VA-API in Jellyfin's playback settings,
        # H.264 only.
        LIBVA_DRIVER_NAME = "i965";
      };
      volumes = [
        "/var/lib/jellyfin/config:/config"
        "/tank/media:/media"
      ];
      ports = [ "8096:8096" ];
      autoStart = true;
      extraOptions = [
        "--network=mhrlab"
        "--device=/dev/dri:/dev/dri"
      ];
    };
  };

  systemd.services.docker-qbittorrent = needsTank;
  systemd.services.docker-jellyfin = needsTank;

  systemd.tmpfiles.rules = [
    "d /var/lib/qbittorrent 0755 jozef users - -"
    "d /var/lib/qbittorrent/config 0755 jozef users - -"
    "d /var/lib/jellyfin 0755 root root - -"
    "d /var/lib/jellyfin/config 0755 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [
    8081 # qBittorrent web UI
    8096 # Jellyfin
    6881 # BitTorrent
  ];
  networking.firewall.allowedUDPPorts = [ 6881 ];
}
