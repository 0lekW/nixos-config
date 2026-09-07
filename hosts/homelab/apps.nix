# Dashboard, file browser, game server, my own web apps.
{ config, ... }:

{
  virtualisation.oci-containers.containers = {
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

  };

  sops.secrets.closet_env = { };
  sops.secrets.vikunja_env = { };

  systemd.tmpfiles.rules = [
    "d /var/lib/filebrowser 0755 olek docker - -"
    "d /srv/minecraft 0755 olek docker - -"
    "d /srv/minecraft/backups 0755 olek docker - -"
    "d /srv/minecraft/logs 0755 olek docker - -"
    "d /srv/minecraft/servers 0755 olek docker - -"
    "d /srv/minecraft/config 0755 olek docker - -"
    "d /var/lib/oleks-closet 0755 olek docker - -"
    "d /var/lib/oleks-closet/data 0755 olek docker - -"
    "d /var/lib/oleks-closet/uploads 0755 olek docker - -"
    "d /var/lib/vikunja 0755 olek docker - -"
  ];

  networking.firewall.allowedTCPPorts = [
    8000 # Crafty web UI
    8080 # Glance dashboard
    8090 # FileBrowser
    8761 # cjsonfmt-ui
    8762 # oleks-closet
    8763 # Vikunja
    25565 # Minecraft
  ];
}
