import json
import os
import urllib.error
import urllib.request


class ImmichAPI:
    def __init__(self, url=None, api_key=None):
        self.url = url or os.environ.get("IMMICH_API_URL", "http://photos.mel.home/api")
        self.api_key = api_key or os.environ["IMMICH_API_KEY"]

    def request(self, method, path, data=None):
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(f"{self.url}{path}", data=body, method=method)
        req.add_header("x-api-key", self.api_key)
        if body:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status == 204 or resp.length == 0:
                    return None
                return json.load(resp)
        except urllib.error.HTTPError as e:
            try:
                body = json.loads(e.read().decode())
                message = body.get("message", body)
            except json.JSONDecodeError, UnicodeDecodeError:
                message = e.reason
            raise ImmichError(e.code, method, path, message) from e

    def search_metadata(self, **kwargs):
        result = self.request("POST", "/search/metadata", kwargs)
        return result["assets"]["items"]

    def update_assets(self, ids, **kwargs):
        self.request("PUT", "/assets", {"ids": ids, **kwargs})

    def get_album(self, album_id):
        return self.request("GET", f"/albums/{album_id}")

    def add_assets_to_album(self, album_id, asset_ids):
        self.request("PUT", f"/albums/{album_id}/assets", {"ids": asset_ids})

    def remove_assets_from_album(self, album_id, asset_ids):
        self.request("DELETE", f"/albums/{album_id}/assets", {"ids": asset_ids})


class ImmichError(Exception):
    def __init__(self, status, method, path, message):
        self.status = status
        self.method = method
        self.path = path
        self.message = message

    def __str__(self):
        return f"Immich API error: {self.method} {self.path} ({self.status}): {self.message}"
