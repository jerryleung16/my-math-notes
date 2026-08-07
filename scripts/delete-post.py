#!/usr/bin/env python3
import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Delete a post folder, rebuild the Quarto site, and publish it."
    )
    parser.add_argument(
        "post_path",
        help="Path to the post directory, for example: posts/python/intro-to-class or python/intro-to-class",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would happen without deleting anything",
    )
    parser.add_argument(
        "--skip-publish",
        action="store_true",
        help="Skip the GitHub Pages publish step",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    post_path_arg = Path(args.post_path)

    if post_path_arg.is_absolute():
        print("Please pass a repository-relative path, such as posts/python/intro-to-class.", file=sys.stderr)
        return 2

    if post_path_arg.parts and post_path_arg.parts[0] == "posts":
        target = repo_root / post_path_arg
    else:
        target = repo_root / "posts" / post_path_arg

    if target == repo_root / "posts":
        print("Please target a specific post folder, not the posts directory itself.", file=sys.stderr)
        return 2

    if not target.exists() or not target.is_dir():
        print(f"Post folder not found: {target.relative_to(repo_root)}", file=sys.stderr)
        return 2

    print(f"Target post folder: {target.relative_to(repo_root)}")

    if args.dry_run:
        print("Dry run only — nothing was deleted.")
        print("Would run: quarto render")
        if not args.skip_publish:
            print("Would run: quarto publish gh-pages --no-prompt")
        return 0

    shutil.rmtree(target)
    print(f"Deleted {target.relative_to(repo_root)}")

    print("Rebuilding the site...")
    subprocess.run(["quarto", "render"], cwd=repo_root, check=True)

    if not args.skip_publish:
        print("Publishing to GitHub Pages...")
        subprocess.run(["quarto", "publish", "gh-pages", "--no-prompt"], cwd=repo_root, check=True)

    print("Delete complete. If the site still looks old, do a hard refresh (Ctrl+F5).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
