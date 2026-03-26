import argparse
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from immich.api import ImmichAPI, ImmichError


def adb_query(adb, uri, projection, where):
    result = subprocess.run(
        [
            adb,
            "shell",
            f'content query --uri {uri} --projection {projection} --where "{where}"',
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode != 0:
        sys.exit(f"adb failed: {result.stderr.strip()}")
    rows = []
    for line in result.stdout.splitlines():
        row = dict(re.findall(r"(\w+)=([^,\s]+)", line))
        if row:
            rows.append(row)
    return rows


def main():
    parser = argparse.ArgumentParser(description="Sync Android favorites to Immich")
    parser.add_argument(
        "--dry-run", action="store_true", help="Only show what would be done"
    )
    parser.add_argument("--adb", default="adb", help="Path to adb binary")
    args = parser.parse_args()

    try:
        api = ImmichAPI()
    except KeyError:
        sys.exit("Error: IMMICH_API_KEY environment variable is not set")

    print("Querying favorites from Android MediaStore...")
    rows = adb_query(
        args.adb,
        "content://media/external/images/media",
        "_display_name:is_favorite",
        "is_favorite=1",
    )

    filenames = [row["_display_name"] for row in rows]
    if not filenames:
        sys.exit("No favorites found on device.")

    print(f"Processing {len(filenames)} favorites...")

    try:
        ids_to_favorite = []
        not_found = []
        already_fav = []

        def search(fname):
            items = api.search_metadata(originalFileName=fname, size=1)
            return fname, items

        done = 0
        with ThreadPoolExecutor(max_workers=8) as pool:
            futures = {pool.submit(search, fname): fname for fname in filenames}
            for future in as_completed(futures):
                fname, items = future.result()
                if not items:
                    not_found.append(fname)
                elif items[0]["isFavorite"]:
                    already_fav.append(fname)
                else:
                    ids_to_favorite.append(items[0]["id"])
                done += 1
                if done % 50 == 0:
                    print(f"  searched {done}/{len(filenames)}...")

        print("Results:")
        print(f"  To favorite: {len(ids_to_favorite)}")
        print(f"  Already favorited: {len(already_fav)}")
        print(f"  Not found in Immich: {len(not_found)}")

        if not_found:
            print(
                f"\nNot found: {not_found[:10]}{'...' if len(not_found) > 10 else ''}"
            )

        if ids_to_favorite:
            if args.dry_run:
                print(f"\nDry run: would favorite {len(ids_to_favorite)} assets.")
            else:
                for start in range(0, len(ids_to_favorite), 100):
                    batch = ids_to_favorite[start : start + 100]
                    api.update_assets(batch, isFavorite=True)
                    print(f"  Updated batch {start // 100 + 1} ({len(batch)} assets)")
                print(f"\nDone! Favorited {len(ids_to_favorite)} assets.")
        else:
            print("\nNothing to update.")
    except ImmichError as e:
        sys.exit(f"Error: {e}")
