"""Gate 1 evidence only: download public inputs without changing project data.

Run from the project root: python3 R/00_verify_downloads.py
Uses only Python's standard library. Existing snapshots are never overwritten.
"""
import concurrent.futures
import csv
import datetime
import hashlib
from pathlib import Path
import urllib.request
import urllib.parse
import ssl
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output/source_verification"
OUT.mkdir(parents=True, exist_ok=True)


def fetch(row):
    result = dict(row)
    result["attempted_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    suffix = Path(urllib.parse.urlsplit(row["url"]).path).suffix
    try:
        request = urllib.request.Request(row["url"], headers={"User-Agent": "MDATA600-source-audit/1.0"})
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                body = response.read()
                result.update(http_status=response.status, content_type=response.headers.get("Content-Type", ""))
        except urllib.error.URLError as error:
            if not isinstance(error.reason, ssl.SSLCertVerificationError):
                raise
            # macOS curl uses the OS trust store; keep TLS verification enabled.
            with tempfile.NamedTemporaryFile() as temporary:
                process = subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error",
                    "--connect-timeout", "10", "--max-time", "45", "--output", temporary.name,
                    "--write-out", "%{http_code}|%{content_type}", row["url"]], capture_output=True, text=True)
                if process.returncode:
                    raise RuntimeError(process.stderr.strip())
                body = Path(temporary.name).read_bytes()
                status, content_type = process.stdout.split("|", 1)
                result.update(http_status=status, content_type=content_type)
        digest = hashlib.sha256(body).hexdigest()
        path = OUT / (row["source_id"] + "_" + digest[:12] + suffix)
        if not path.exists():
            with path.open("xb") as handle:
                handle.write(body)
        result.update(bytes=len(body), sha256=digest, snapshot=str(path.relative_to(ROOT)), error="")
    except Exception as error:
        result.update(http_status="", content_type="", bytes=0, sha256="", snapshot="", error=str(error))
    print(row["source_id"], result.get("http_status"), result["bytes"], result["error"], flush=True)
    return result


if __name__ == "__main__":
    with (ROOT / "docs/evidence/source_urls.csv").open() as handle:
        rows = list(csv.DictReader(handle))
    if len(sys.argv) > 1:
        rows = [row for row in rows if row["source_id"].startswith(sys.argv[1])]
    if not rows:
        raise SystemExit("No matching sources")
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(fetch, rows))
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    with (ROOT / f"docs/evidence/download_attempts_{stamp}.csv").open("x") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(results[0]))
        writer.writeheader()
        writer.writerows(results)
