# Metrics exporters scraped by Prometheus on the homelab host.
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
      autoStart = true;
    };

    # Host port 8089 to avoid colliding with FileBrowser on 8080.
    cadvisor = {
      image = "gcr.io/cadvisor/cadvisor@sha256:3cde6faf0791ebf7b41d6f8ae7145466fed712ea6f252c935294d2608b1af388";
      ports = [ "8089:8080" ];
      volumes = [
        "/:/rootfs:ro"
        "/var/run:/var/run:ro"
        "/sys:/sys:ro"
        "/var/lib/docker/:/var/lib/docker:ro"
      ];
      extraOptions = [ "--privileged" ];
      autoStart = true;
    };

  };

  networking.firewall.allowedTCPPorts = [
    9100 # node-exporter
    8089 # cAdvisor
  ];
}
