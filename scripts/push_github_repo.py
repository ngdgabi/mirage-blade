#!/usr/bin/env python3
"""
Creates or updates the public GitHub repository 'ngdgabi/mirage-blade'
and pushes the clean Mirage Blade: Hourglass Universal Swift codebase & Storefront Kit.
"""

import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = "mirage-blade"


def gh_api(method: str, path: str, token: str, payload: dict = None):
    url = f"https://api.github.com{path}"
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("User-Agent", "NGD-MirageBlade-Publisher")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        return e.code, {"raw": raw}


def main():
    token = os.environ.get("GH_TOKEN", "").strip()
    if "--token" in sys.argv:
        idx = sys.argv.index("--token")
        if idx + 1 < len(sys.argv):
            token = sys.argv[idx + 1].strip()
    if not token:
        sys.exit("Usage: python3 push_github_repo.py --token ghp_...")

    st, u = gh_api("GET", "/user", token)
    if st != 200:
        sys.exit(f"GitHub auth failed ({st}): {u}")
    login = u["login"]

    st_repo, _ = gh_api("GET", f"/repos/{login}/{REPO}", token)
    if st_repo == 404:
        print(f"==> Creating public repository {login}/{REPO}...")
        cs, cb = gh_api("POST", "/user/repos", token, {
            "name": REPO,
            "description": "Mirage Blade: Hourglass — Native 120Hz Universal Arabian Dungeon Action-Platformer & Scimitar Fencing Game for macOS, iOS & iPadOS (© 2026 NGD)",
            "homepage": "https://ngdgabi.github.io/star-viper/mirage-blade/",
            "private": False,
            "has_issues": True,
            "auto_init": False,
        })
        if cs not in (200, 201):
            sys.exit(f"Repo create failed ({cs}): {cb}")

    remote_url = f"https://github.com/{login}/{REPO}.git"
    subprocess.run(["git", "-C", PROJECT_DIR, "remote", "remove", "origin"], capture_output=True)
    subprocess.run(["git", "-C", PROJECT_DIR, "remote", "add", "origin", remote_url], check=True)
    basic = base64.b64encode(f"x-access-token:{token}".encode("utf-8")).decode("ascii")
    subprocess.run([
        "git", "-C", PROJECT_DIR,
        "-c", f"http.https://github.com/.extraheader=AUTHORIZATION: basic {basic}",
        "push", "-u", "origin", "main", "--force"
    ], check=True)
    print(f"SUCCESS! Published https://github.com/{login}/{REPO}")


if __name__ == "__main__":
    main()
