let
  user_jakob = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/7y7H/M64OslBJvrMA+s+eF1P4MJVf0hx/Gw4zoQXC jakob@me";
  users = [ user_jakob ];

  system_mel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWoG4HDLUHzUvfuzu0XyvnrNb0RY4DzVnbrM1sgEk8L root@mel";
  systems = [ system_mel ];

  names = [
    "ssh-github"
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
