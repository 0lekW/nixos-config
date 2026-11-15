# Immich photo backup. Library on tank/photos, database on the SSD.
# Same images and layout as the one on homelab_zfs.
{ config, ... }:

let
  needsTank = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    unitConfig.ConditionPathIsMountPoint = "/tank/photos";
  };
in
{
  virtualisation.oci-containers.containers = {
    immich-server = {
      image = "ghcr.io/immich-app/immich-server:v2.7.5@sha256:c15bff75068effb03f4355997d03dc7e0fc58720c2b54ad6f7f10d1bc57efaa5";
      ports = [ "2283:2283" ];
      # DB_PASSWORD
      environmentFiles = [ config.sops.secrets.immich_env.path ];
      dependsOn = [
        "immich-redis"
        "immich-postgres"
      ];
      environment = {
        TZ = "Pacific/Auckland";
        DB_HOSTNAME = "immich-postgres";
        DB_USERNAME = "postgres";
        DB_DATABASE_NAME = "immich";
        REDIS_HOSTNAME = "immich-redis";
      };
      volumes = [ "/tank/photos:/data" ];
      autoStart = true;
      extraOptions = [ "--network=mhrlab" ];
    };

    # Face and object search. Slow on the i5-2400, but it only works through
    # the backlog once.
    immich-machine-learning = {
      image = "ghcr.io/immich-app/immich-machine-learning:v2.7.5@sha256:a2501141440f10516d329fdfba2c68082e19eb9ba6016c061ac80d23beadf7f3";
      volumes = [ "/var/lib/immich/model-cache:/cache" ];
      autoStart = true;
      extraOptions = [ "--network=mhrlab" ];
    };

    immich-redis = {
      image = "docker.io/valkey/valkey:9@sha256:4963247afc4cd33c7d3b2d2816b9f7f8eeebab148d29056c2ca4d7cbc966f2d9";
      autoStart = true;
      extraOptions = [ "--network=mhrlab" ];
    };

    immich-postgres = {
      image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
      # POSTGRES_PASSWORD
      environmentFiles = [ config.sops.secrets.immich_env.path ];
      environment = {
        POSTGRES_USER = "postgres";
        POSTGRES_DB = "immich";
      };
      volumes = [ "/var/lib/immich/postgres:/var/lib/postgresql/data" ];
      autoStart = true;
      extraOptions = [ "--network=mhrlab" ];
    };
  };

  sops.secrets.immich_env = { };

  systemd.services.docker-immich-server = needsTank;

  systemd.tmpfiles.rules = [
    "d /var/lib/immich 0750 root root - -"
    "d /var/lib/immich/model-cache 0750 root root - -"
    "d /var/lib/immich/postgres 0700 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [ 2283 ];
}
