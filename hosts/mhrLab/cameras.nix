# Frigate NVR for the four Dahua cameras.
#
# Only the container is declared here. Cameras, detection and recording
# retention live in Frigate's own config.yml under /var/lib/frigate/config,
# which Frigate creates on first start and you edit from its web UI.
# Recordings go to tank/frigate; set a retention there or they fill the pool.
#
# No GPU passthrough: the Sandy Bridge iGPU can't decode the NVR's H.265 and
# its VA-API scaler fails even on H.264, and Frigate auto-picks VA-API when it
# sees /dev/dri. Decoding the small detect streams on the CPU is cheap enough.
{ config, ... }:

{
  virtualisation.oci-containers.containers.frigate = {
    image = "ghcr.io/blakeblackshear/frigate:0.18.2@sha256:fd60f99ffd4eb6c42360ed4e14953e270586f239309ab3983e55b2e97ffac09a";
    environment = {
      TZ = "Pacific/Auckland";
    };
    # FRIGATE_RTSP_USER / FRIGATE_RTSP_PASSWORD for the NVR, so config.yml can
    # say {FRIGATE_RTSP_PASSWORD} instead of holding the password.
    environmentFiles = [ config.sops.secrets.frigate_env.path ];
    volumes = [
      "/var/lib/frigate/config:/config"
      "/tank/frigate:/media/frigate"
    ];
    ports = [
      "8971:8971" # Web UI (with login)
      "8554:8554" # RTSP restream
      "8555:8555/tcp" # WebRTC
      "8555:8555/udp" # WebRTC
    ];
    autoStart = true;
    extraOptions = [
      "--network=mhrlab"
      "--shm-size=512m"
      "--tmpfs=/tmp/cache:size=1g"
    ];
  };

  sops.secrets.frigate_env = { };

  systemd.services.docker-frigate = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    unitConfig.ConditionPathIsMountPoint = "/tank/frigate";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/frigate 0755 root root - -"
    "d /var/lib/frigate/config 0755 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [
    8971 # Frigate UI
    8554 # RTSP
    8555 # WebRTC
  ];
  networking.firewall.allowedUDPPorts = [ 8555 ];
}
