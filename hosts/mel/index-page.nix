{
  pkgs,
  lib,
  serviceDescriptions,
}:
let
  serviceLinks = lib.concatMapStringsSep "\n          " (
    svc: "<li><a href=\"http://${svc.domain}\">${svc.title}</a></li>"
  ) serviceDescriptions;

  htmlFile = pkgs.writeText "index.html" ''
    <!doctype html>
    <html>
      <head>
        <title>Services</title>
        <style>
          body {
            font-family: system-ui;
            max-width: 600px;
            margin: 100px auto;
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
      </body>
    </html>
  '';
in
pkgs.runCommand "index-page-dir" { } ''
  mkdir -p $out
  ln -s ${htmlFile} $out/index.html
''
