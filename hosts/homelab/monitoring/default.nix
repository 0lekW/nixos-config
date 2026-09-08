# Metrics and dashboards. Scrape config and dashboard JSON live beside this file.
# the provisioned datasource and dashboards, and the containers below.
{ ... }:

{
  virtualisation.oci-containers.containers = {

    nodeexporter = {
      image = "prom/node-exporter@sha256:d00a542e409ee618a4edc67da14dd48c5da66726bbd5537ab2af9c1dfc442c8a";
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
      extraOptions = [ "--network=homelab" ];
      autoStart = true;
    };

    prometheus = {
      image = "prom/prometheus@sha256:63805ebb8d2b3920190daf1cb14a60871b16fd38bed42b857a3182bc621f4996";
      ports = [ "9090:9090" ];
      volumes = [
        "/var/lib/prometheus:/prometheus"
        "${./prometheus.yml}:/etc/prometheus/prometheus.yml:ro"
      ];
      autoStart = true;
      extraOptions = [ "--network=homelab" ];
    };

    cadvisor = {
      image = "gcr.io/cadvisor/cadvisor@sha256:3cde6faf0791ebf7b41d6f8ae7145466fed712ea6f252c935294d2608b1af388";
      volumes = [
        "/:/rootfs:ro"
        "/var/run:/var/run:ro"
        "/sys:/sys:ro"
        "/var/lib/docker/:/var/lib/docker:ro"
      ];
      extraOptions = [
        "--privileged"
        "--network=homelab"
      ];
      autoStart = true;
    };

    grafana = {
      image = "grafana/grafana@sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d";
      ports = [ "3000:3000" ];
      volumes = [
        "/var/lib/grafana:/var/lib/grafana"
        "${./grafana/provisioning}:/etc/grafana/provisioning:ro"
        "${./grafana/dashboards}:/etc/grafana/dashboards:ro"
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

    # Live container logs in the browser. The socket is mounted read-only,
    # but it still exposes full control of the daemon to anyone who reaches it.
    dozzle = {
      image = "amir20/dozzle:v10.10.0@sha256:2875e3c1f31f2244ee99d6067b53852b30666b3e2fb293d179bc8be94b1da5eb";
      ports = [ "8087:8080" ];
      # Pulls in the containers running on the ZFS box via its Dozzle agent.
      environment.DOZZLE_REMOTE_AGENT = "192.168.1.201:7007";
      volumes = [ "/var/run/docker.sock:/var/run/docker.sock:ro" ];
      autoStart = true;
      extraOptions = [ "--network=homelab" ];
    };

  };

  # Prometheus runs as nobody, Grafana as uid 472, hence the odd owners.
  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus 0770 65534 65534 - -"
    "d /var/lib/grafana 0755 472 472 - -"
  ];

  networking.firewall.allowedTCPPorts = [
    3000 # Grafana
    9090 # Prometheus
    9100 # node-exporter
    8087 # Dozzle
  ];
}
