from __future__ import annotations

import argparse
import re
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend-root", required=True)
    args = ap.parse_args()

    path = Path(args.backend_root).resolve() / "controllers" / "customerDebtController.js"
    text = path.read_text(encoding="utf-8")

    # If already patched, do nothing.
    if re.search(r"const collection = await CustomerDebtCollection\.create\(\{\s*[\r\n]+\s*snapshotId:\s*snapshot\._id", text):
        print("Already patched.")
        return

    # Insert snapshotId right after the opening create({ of the single-collection handler.
    pat = r"(const collection = await CustomerDebtCollection\.create\(\{)(\r?\n)"
    m = re.search(pat, text)
    if not m:
        raise SystemExit("Could not find CustomerDebtCollection.create({ for single collection.")

    text2 = re.sub(pat, r"\1\2      snapshotId: snapshot._id,\2", text, count=1)
    path.write_text(text2, encoding="utf-8")
    print("Patched snapshotId in createCollection.")


if __name__ == "__main__":
    main()

