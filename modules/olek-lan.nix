# The two homelab machines on Olek's LAN: same router, same admin user.
{ ... }:

{
  networking.useDHCP = false;
  networking.defaultGateway = "192.168.1.254";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  users.users.olek = {
    isNormalUser = true;
    description = "Alex Wardega";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
  };
}
