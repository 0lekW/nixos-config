# The two 4TB HDDs striped into one ZFS pool ("tank", ~7TB, no redundancy:
# lose either disk and the whole pool is gone), and a Samba share on it.
#
# The pool and its datasets are created once by hand (see README); this file
# only imports, scrubs and shares them.
#   tank/shared   general files, shared over Samba
#   tank/media    qBittorrent downloads and the Jellyfin library
#   tank/photos   Immich library
#   tank/frigate  camera recordings
{ pkgs, ... }:

{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "tank" ];
  # Root is ext4, so the forced root-pool import never applies; false is the
  # safer default from 26.11 on.
  boot.zfs.forceImportRoot = false;

  services.zfs.autoScrub.enable = true; # monthly integrity check

  environment.systemPackages = [ pkgs.zfs ];

  systemd.tmpfiles.rules = [
    "d /tank/shared 0775 jozef users -"
    "d /tank/media 0775 jozef users -"
    "d /tank/media/downloads 0775 jozef users -"
  ];

  # SMB shares, LAN only. Samba keeps its own password: `sudo smbpasswd -a jozef`.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "mhrLab";
        "security" = "user";
        "hosts allow" = "192.168.0.0/24";
        "map to guest" = "bad user";
      };

      shared = {
        "path" = "/tank/shared";
        "browseable" = "yes";
        "writable" = "yes";
        "guest ok" = "no";
        "valid users" = "jozef";
        "force user" = "jozef";
        "create mask" = "0664";
        "directory mask" = "0775";
      };

      # Drop films and shows in here for Jellyfin.
      media = {
        "path" = "/tank/media";
        "browseable" = "yes";
        "writable" = "yes";
        "guest ok" = "no";
        "valid users" = "jozef";
        "force user" = "jozef";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  # Lets Windows find the box under Network.
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
