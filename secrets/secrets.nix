let
  user_jakob = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/7y7H/M64OslBJvrMA+s+eF1P4MJVf0hx/Gw4zoQXC jakob@me";
  user_sipgatejj = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/s4OVz67odrG1c2tww9XBoeZmv2on2bEo+qao81mt0 sipgatejj";
  users = [
    user_jakob
    user_sipgatejj
  ];

  system_mel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWoG4HDLUHzUvfuzu0XyvnrNb0RY4DzVnbrM1sgEk8L root@mel";
  systems = [ system_mel ];

  names = [
    "wifi-password-env"
    "ssh-github"
    "tailscale-authkey"
    "duckdns-token-env"
    "desec-token-env"
  ];
in
builtins.listToAttrs (
  map (name: {
    name = name + ".age";
    value = {
      publicKeys = users ++ systems;
      armor = true;
    };
  }) names
)
