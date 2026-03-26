import argparse
import json
import sys

from immich.api import ImmichAPI, ImmichError

FILTERS = {"favorites"}


def sync_rule(api, rule, dry_run):
    base_id = rule["base"]
    target_id = rule["target"]
    filter_name = rule["filter"]

    if filter_name not in FILTERS:
        sys.exit(f"Unknown filter: {filter_name!r} (available: {FILTERS})")

    base = api.get_album(base_id)
    target = api.get_album(target_id)

    print(
        f"Rule: {base['albumName']!r} -> {target['albumName']!r} (filter: {filter_name})"
    )

    if filter_name == "favorites":
        wanted = {a["id"] for a in base["assets"] if a["isFavorite"]}

    current = {a["id"] for a in target["assets"]}

    to_add = wanted - current
    to_remove = current - wanted

    print(f"  Base has {len(base['assets'])} assets, {len(wanted)} match filter")
    print(f"  Target has {len(current)} assets")
    print(f"  To add: {len(to_add)}, to remove: {len(to_remove)}")

    if dry_run:
        return

    if to_add:
        api.add_assets_to_album(target_id, list(to_add))
    if to_remove:
        api.remove_assets_from_album(target_id, list(to_remove))


def main():
    parser = argparse.ArgumentParser(
        description="Sync Immich albums based on filter rules"
    )
    parser.add_argument("rules", help="Path to JSON rules file")
    parser.add_argument(
        "--dry-run", action="store_true", help="Only show what would be done"
    )
    args = parser.parse_args()

    with open(args.rules) as f:
        rules = json.load(f)

    try:
        api = ImmichAPI()
    except KeyError:
        sys.exit("Error: IMMICH_API_KEY environment variable is not set")

    try:
        for rule in rules:
            sync_rule(api, rule, args.dry_run)
    except ImmichError as e:
        sys.exit(f"Error: {e}")

    print("\nDone." if not args.dry_run else "\nDry run complete.")
