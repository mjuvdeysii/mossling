#!/usr/bin/env python3
"""Update TestFlight 'What to Test' (betaBuildLocalizations.whatsNew) via App Store Connect API.

Uses only Python 3 standard library + `openssl` (preinstalled on macOS/Linux) so CI needs no pip installs.
Reads the latest version section from ios/Docs/CHANGELOG.md, polls App Store Connect until the uploaded
build appears, and creates/updates the zh-Hans betaBuildLocalization.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

API_BASE = "https://api.appstoreconnect.apple.com/v1"
MAX_WHATS_NEW_CHARS = 4000


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_ecdsa_to_raw(der: bytes, size: int = 32) -> bytes:
    """Convert an ASN.1 DER-encoded ECDSA signature (SEQUENCE { INTEGER r, INTEGER s }) to raw r||s."""
    idx = 0
    if idx >= len(der) or der[idx] != 0x30:
        raise ValueError("Invalid DER signature: missing SEQUENCE tag")
    idx += 1
    seq_len = der[idx]
    idx += 1
    if seq_len & 0x80:
        nbytes = seq_len & 0x7F
        idx += nbytes

    def read_int() -> bytes:
        nonlocal idx
        if idx >= len(der) or der[idx] != 0x02:
            raise ValueError("Invalid DER signature: missing INTEGER tag")
        idx += 1
        length = der[idx]
        idx += 1
        if length & 0x80:
            n = length & 0x7F
            length = int.from_bytes(der[idx : idx + n], "big")
            idx += n
        val = der[idx : idx + length]
        idx += length
        val = val.lstrip(b"\x00")
        if len(val) > size:
            raise ValueError(f"ECDSA integer too large: {len(val)} > {size}")
        return val.rjust(size, b"\x00")

    r = read_int()
    s = read_int()
    return r + s


def make_jwt(key_id: str, issuer_id: str, key_path: str, ttl_seconds: int = 1000) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + ttl_seconds,
        "aud": "appstoreconnect-v1",
    }
    signing_input = f"{b64url(json.dumps(header, separators=(',', ':')).encode())}.{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    proc = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input.encode("ascii"),
        capture_output=True,
        check=True,
    )
    raw_sig = der_ecdsa_to_raw(proc.stdout, 32)
    return f"{signing_input}.{b64url(raw_sig)}"


def extract_changelog(changelog_path: str, version: str | None = None, build: str | None = None) -> str:
    """Extract the matching version section (or the top-most ## section) as clean TestFlight plain text."""
    with open(changelog_path, encoding="utf-8") as f:
        lines = f.read().splitlines()

    sections: list[tuple[str, list[str]]] = []
    cur_ver: str | None = None
    cur_lines: list[str] = []
    for line in lines:
        if line.startswith("## "):
            if cur_ver is not None:
                sections.append((cur_ver, cur_lines))
            cur_ver = line[3:].strip()
            cur_lines = []
        elif cur_ver is not None:
            cur_lines.append(line)
    if cur_ver is not None:
        sections.append((cur_ver, cur_lines))

    if not sections:
        raise ValueError(f"No ## version sections found in {changelog_path}")

    chosen_ver, chosen_lines = sections[0]
    if version:
        for sec_ver, sec_lines in sections:
            if sec_ver == version or sec_ver.startswith(version + " "):
                chosen_ver, chosen_lines = sec_ver, sec_lines
                break

    cleaned: list[str] = []
    for raw in chosen_lines:
        s = raw.strip()
        if not s:
            continue
        # Strip markdown bold/code formatting and ASC-disallowed Unicode symbols (category So, e.g. checkmarks/emoji)
        s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
        s = re.sub(r"`([^`]+)`", r"\1", s)
        s = "".join(ch for ch in s if unicodedata.category(ch) != "So")
        s = re.sub(r"\s{2,}", " ", s).strip()
        if s.startswith("- "):
            s = "• " + s[2:]
        cleaned.append(s)

    header = f"v{chosen_ver}" + (f" (Build {build})" if build else "")
    text = header + "\n" + "\n".join(cleaned)
    if len(text) > MAX_WHATS_NEW_CHARS:
        text = text[: MAX_WHATS_NEW_CHARS - 1] + "…"
    return text


class ASCClient:
    def __init__(self, key_id: str, issuer_id: str, key_path: str):
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.key_path = key_path
        self._token = ""
        self._token_exp = 0.0

    def _get_token(self) -> str:
        now = time.time()
        if not self._token or now >= self._token_exp - 60:
            self._token = make_jwt(self.key_id, self.issuer_id, self.key_path, ttl_seconds=1000)
            self._token_exp = now + 1000
        return self._token

    def request(self, method: str, path: str, body: dict | None = None, max_attempts: int = 3) -> dict:
        url = path if path.startswith("http") else f"{API_BASE}{path}"
        data = json.dumps(body).encode("utf-8") if body is not None else None
        for attempt in range(1, max_attempts + 1):
            req = urllib.request.Request(url, data=data, method=method)
            req.add_header("Authorization", f"Bearer {self._get_token()}")
            req.add_header("Accept", "application/json")
            if data is not None:
                req.add_header("Content-Type", "application/json")
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    raw = resp.read()
                    return json.loads(raw.decode("utf-8")) if raw else {}
            except urllib.error.HTTPError as e:
                detail = e.read().decode("utf-8", errors="replace")
                if e.code in (429, 500, 502, 503, 504) and attempt < max_attempts:
                    time.sleep(min(8, 2**attempt))
                    continue
                raise RuntimeError(f"ASC {method} {path} failed ({e.code}): {detail}") from e
            except urllib.error.URLError as e:
                if attempt < max_attempts:
                    time.sleep(min(8, 2**attempt))
                    continue
                raise RuntimeError(f"ASC {method} {path} network error: {e}") from e
        raise RuntimeError(f"ASC {method} {path} exhausted retries")


def upsert_beta_localization(client: ASCClient, build_id: str, build_number: str, state: str, locale: str, whats_new: str) -> str:
    locs = client.request("GET", f"/builds/{build_id}/betaBuildLocalizations").get("data", [])
    existing = next((x for x in locs if x.get("attributes", {}).get("locale") == locale), None)

    if existing:
        loc_id = existing["id"]
        client.request(
            "PATCH",
            f"/betaBuildLocalizations/{loc_id}",
            {
                "data": {
                    "type": "betaBuildLocalizations",
                    "id": loc_id,
                    "attributes": {"whatsNew": whats_new},
                }
            },
        )
        return f"updated existing {locale} localization (id={loc_id}) for build {build_number} (state={state})"

    try:
        created = client.request(
            "POST",
            "/betaBuildLocalizations",
            {
                "data": {
                    "type": "betaBuildLocalizations",
                    "attributes": {"locale": locale, "whatsNew": whats_new},
                    "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
                }
            },
        )
        loc_id = created.get("data", {}).get("id", "unknown")
        return f"created {locale} localization (id={loc_id}) for build {build_number} (state={state})"
    except RuntimeError as exc:
        if "(409)" in str(exc):
            locs = client.request("GET", f"/builds/{build_id}/betaBuildLocalizations").get("data", [])
            existing = next((x for x in locs if x.get("attributes", {}).get("locale") == locale), None)
            if existing:
                loc_id = existing["id"]
                client.request(
                    "PATCH",
                    f"/betaBuildLocalizations/{loc_id}",
                    {
                        "data": {
                            "type": "betaBuildLocalizations",
                            "id": loc_id,
                            "attributes": {"whatsNew": whats_new},
                        }
                    },
                )
                return f"updated existing {locale} localization after 409 (id={loc_id}) for build {build_number} (state={state})"
        raise


def fetch_recent_builds_summary(client: ASCClient, app_id: str, limit: int = 5) -> str:
    try:
        q = urllib.parse.urlencode({"filter[app]": app_id, "sort": "-uploadedDate", "limit": str(limit)})
        recent = client.request("GET", f"/builds?{q}").get("data", [])
        if not recent:
            return "(no builds returned by ASC)"
        parts = []
        for b in recent:
            attrs = b.get("attributes", {})
            parts.append(
                f"#{attrs.get('version', '?')}[{attrs.get('processingState', '?')}@{str(attrs.get('uploadedDate', ''))[:19]}]"
            )
        return ", ".join(parts)
    except Exception as exc:
        return f"(failed to list recent builds: {exc})"


def update_whats_new(
    client: ASCClient,
    bundle_id: str,
    build_number: str,
    version: str | None,
    localized_notes: list[tuple[str, str]],
    timeout_seconds: int = 1800,
    poll_interval: int = 20,
) -> list[str]:
    q = urllib.parse.urlencode({"filter[bundleId]": bundle_id, "limit": "50"})
    apps = client.request("GET", f"/apps?{q}").get("data", [])
    if not apps:
        raise RuntimeError(f"No app found in App Store Connect for bundleId={bundle_id}")
    exact_app = next(
        (a for a in apps if a.get("attributes", {}).get("bundleId") == bundle_id),
        None,
    )
    if exact_app is None:
        found = [a.get("attributes", {}).get("bundleId", "?") for a in apps]
        raise RuntimeError(f"No exact bundleId={bundle_id} match in App Store Connect (candidates: {found})")
    app_id = exact_app["id"]
    app_name = exact_app.get("attributes", {}).get("name", "?")
    print(f"[ASC] Matched exact bundleId={bundle_id} -> app_id={app_id} ({app_name})", flush=True)

    # Also backfill the most recent already-VALID build (e.g. build 463) if its What-to-Test is still blank
    try:
        rq = urllib.parse.urlencode({"filter[app]": app_id, "sort": "-uploadedDate", "limit": "3"})
        recent_builds = client.request("GET", f"/builds?{rq}").get("data", [])
        for rb in recent_builds:
            r_ver = str(rb.get("attributes", {}).get("version", ""))
            r_state = rb.get("attributes", {}).get("processingState", "")
            if r_state == "VALID" and r_ver and r_ver != build_number:
                locs = client.request("GET", f"/builds/{rb['id']}/betaBuildLocalizations").get("data", [])
                zh_loc = next((x for x in locs if x.get("attributes", {}).get("locale") == "zh-Hans"), None)
                if not zh_loc or not (zh_loc.get("attributes", {}).get("whatsNew") or "").strip():
                    for loc, notes in localized_notes:
                        msg = upsert_beta_localization(client, rb["id"], r_ver, r_state, loc, notes)
                        print(f"[ASC] Backfilled recent build #{r_ver}: {msg}", flush=True)
                break
    except Exception as exc:
        print(f"[ASC] Note: recent build backfill skipped: {exc}", flush=True)

    deadline = time.time() + timeout_seconds
    build_id: str | None = None
    state = ""
    attempt = 0

    while time.time() < deadline:
        attempt += 1
        params = {
            "filter[app]": app_id,
            "filter[version]": build_number,
            "limit": "5",
        }
        builds = client.request("GET", f"/builds?{urllib.parse.urlencode(params)}").get("data", [])
        if builds:
            b = builds[0]
            build_id = b["id"]
            state = b.get("attributes", {}).get("processingState", "")
            print(f"[ASC] Found build {build_number} (id={build_id}, state={state})", flush=True)
            if state == "INVALID" or state == "FAILED":
                raise RuntimeError(f"Build {build_number} ended in state {state}")
            if state == "VALID":
                break
        else:
            if attempt == 1 or attempt % 5 == 0:
                summary = fetch_recent_builds_summary(client, app_id)
                print(
                    f"[ASC] Waiting for build {build_number} (v{version or '?'})... latest ASC builds: {summary}",
                    flush=True,
                )
            else:
                print(f"[ASC] Waiting for build {build_number} to appear in App Store Connect...", flush=True)
        time.sleep(poll_interval)

    if not build_id:
        summary = fetch_recent_builds_summary(client, app_id)
        raise RuntimeError(
            f"Timed out waiting for build {build_number} to appear in App Store Connect. Latest ASC builds: {summary}"
        )

    results: list[str] = []
    for locale, notes in localized_notes:
        try:
            results.append(upsert_beta_localization(client, build_id, build_number, state, locale, notes))
        except RuntimeError as exc:
            # Never lose the primary localization if a secondary locale fails unexpectedly
            if not results:
                raise
            print(f"[ASC] Warning: secondary locale {locale} failed: {exc}", flush=True)
    return results


def main() -> int:
    ap = argparse.ArgumentParser(description="Sync CHANGELOG.md to TestFlight What to Test")
    ap.add_argument("--bundle-id", default="app.mossling")
    ap.add_argument("--build", required=True, help="CFBundleVersion (build number)")
    ap.add_argument("--version", default="", help="CFBundleShortVersionString (marketing version)")
    ap.add_argument("--changelog", default="Docs/CHANGELOG.md")
    ap.add_argument("--locale", default="zh-Hans")
    ap.add_argument("--en-changelog", default="", help="Optional English changelog path for en-US localization")
    ap.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID", ""))
    ap.add_argument("--issuer-id", default=os.environ.get("ASC_ISSUER_ID", ""))
    ap.add_argument("--key-path", required=True)
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    localized_notes: list[tuple[str, str]] = [
        (args.locale, extract_changelog(args.changelog, version=args.version or None, build=args.build))
    ]
    if args.en_changelog and os.path.exists(args.en_changelog):
        localized_notes.append(
            ("en-US", extract_changelog(args.en_changelog, version=args.version or None, build=args.build))
        )

    for loc, text in localized_notes:
        print(f"--- TestFlight What to Test ({loc}) ---")
        print(text)
        print("-------------------------------", flush=True)

    if args.dry_run:
        return 0

    if not args.key_id or not args.issuer_id:
        print("Missing ASC_KEY_ID or ASC_ISSUER_ID", file=sys.stderr)
        return 1

    client = ASCClient(args.key_id, args.issuer_id, args.key_path)
    results = update_whats_new(
        client,
        bundle_id=args.bundle_id,
        build_number=args.build,
        version=args.version or None,
        localized_notes=localized_notes,
        timeout_seconds=args.timeout,
    )
    for res in results:
        print(f"::notice title=TestFlight 测试信息::{res}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
