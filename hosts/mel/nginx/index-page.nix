{
  pkgs,
  lib,
  services,
}:

let
  enabledServices = lib.filterAttrs (name: cfg: (cfg.enable or false) && (cfg ? title)) services;
  serviceLinks = lib.concatStringsSep "\n          " (
    lib.mapAttrsToList (
      name: cfg: ''<li><a data-subdomain="${cfg.subdomain}">${cfg.title}</a></li>''
    ) enabledServices
  );

  htmlFile = pkgs.writeText "index.html" ''
    <!doctype html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Services</title>
        <style>
          body {
            font-family: system-ui;
            max-width: 600px;
            margin: 40px auto;
            padding: 0 20px;
            background: #1a1a1a;
            color: #e0e0e0;
          }
          ul {
            list-style: none;
            padding: 0;
          }
          li {
            margin: 20px 0;
          }
          a {
            display: block;
            padding: 20px;
            background: #2a2a2a;
            text-decoration: none;
            color: #e0e0e0;
            border-radius: 8px;
            border: 1px solid #3a3a3a;
            cursor: pointer;
          }
          a:hover {
            background: #333;
            border-color: #4a4a4a;
          }
        </style>
      </head>
      <body>
        <h1>Available Services</h1>
        <ul>
          ${serviceLinks}
        </ul>
        <script>
          const baseDomain = window.location.hostname.replace(/^mel\./, "");
          document.querySelectorAll("a[data-subdomain]").forEach(a => {
            a.href = "http://" + a.dataset.subdomain + ".mel." + baseDomain;
          });
        </script>
      </body>
    </html>
  '';
in
pkgs.runCommand "index-page-dir" { } ''
  mkdir -p $out
  ln -s ${htmlFile} $out/index.html
''
