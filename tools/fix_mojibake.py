import argparse
import os
import re
from pathlib import Path


MOJIBAKE_CHARS_RE = re.compile(r"[ØÙÃâ€™â€œâ€\u00A0]")
RUN_RE = re.compile(r"[^\x00-\x7F]{2,}")
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")

# Reverse map for Windows-1252 extended characters (0x80-0x9F) that decode
# to Unicode code points outside Latin-1. Bytes 0x81/0x8D/0x8F/0x90/0x9D are
# undefined in cp1252, so they are intentionally omitted.
CP1252_CHAR_TO_BYTE = {
    0x20AC: 0x80,  # €
    0x201A: 0x82,  # ‚
    0x0192: 0x83,  # ƒ
    0x201E: 0x84,  # „
    0x2026: 0x85,  # …
    0x2020: 0x86,  # †
    0x2021: 0x87,  # ‡
    0x02C6: 0x88,  # ˆ
    0x2030: 0x89,  # ‰
    0x0160: 0x8A,  # Š
    0x2039: 0x8B,  # ‹
    0x0152: 0x8C,  # Œ
    0x017D: 0x8E,  # Ž
    0x2018: 0x91,  # ‘
    0x2019: 0x92,  # ’
    0x201C: 0x93,  # “
    0x201D: 0x94,  # ”
    0x2022: 0x95,  # •
    0x2013: 0x96,  # –
    0x2014: 0x97,  # —
    0x02DC: 0x98,  # ˜
    0x2122: 0x99,  # ™
    0x0161: 0x9A,  # š
    0x203A: 0x9B,  # ›
    0x0153: 0x9C,  # œ
    0x017E: 0x9E,  # ž
    0x0178: 0x9F,  # Ÿ
}


def looks_like_mojibake(run: str) -> bool:
    if not MOJIBAKE_CHARS_RE.search(run):
        return False
    # Exclude runs that already contain Arabic; they are likely valid.
    if ARABIC_RE.search(run):
        return False
    return True


def _decode_once(run: str) -> str | None:
    try:
        # Many mojibake sequences come from UTF-8 bytes mis-decoded as Windows-1252.
        # To reverse safely, we rebuild the original bytes:
        # - code points 0x00..0xFF map to the same byte value (incl. control chars)
        # - plus the Windows-1252 special chars in 0x80..0x9F range.
        buf = bytearray()
        for ch in run:
            o = ord(ch)
            if o <= 0xFF:
                buf.append(o)
            elif o in CP1252_CHAR_TO_BYTE:
                buf.append(CP1252_CHAR_TO_BYTE[o])
            else:
                return None
        return bytes(buf).decode("utf-8")
    except Exception:
        return None


def try_fix_run(run: str) -> str | None:
    fixed = _decode_once(run)
    if fixed is None:
        return None

    if ARABIC_RE.search(fixed):
        return fixed

    # Some files contain "double mojibake" (UTF-8 decoded incorrectly twice).
    # If the first decode still looks mojibake-ish, try one more pass.
    if fixed != run and MOJIBAKE_CHARS_RE.search(fixed):
        fixed2 = _decode_once(fixed)
        if fixed2 and ARABIC_RE.search(fixed2):
            return fixed2

    return None
    # Only accept if it turns into Arabic text.
    if not ARABIC_RE.search(fixed):
        return None
    return fixed


def fix_text(text: str) -> tuple[str, int]:
    replacements = 0

    def repl(match: re.Match[str]) -> str:
        nonlocal replacements
        run = match.group(0)
        if not looks_like_mojibake(run):
            return run
        fixed = try_fix_run(run)
        if fixed is None:
            return run
        replacements += 1
        return fixed

    # Replace suspicious non-ascii runs.
    return RUN_RE.sub(repl, text), replacements


def process_file(path: Path, dry_run: bool) -> int:
    try:
        original = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return 0

    fixed, count = fix_text(original)
    if count == 0:
        return 0

    if not dry_run:
        path.write_text(fixed, encoding="utf-8", newline="\n")
    return count


def iter_target_files(root: Path):
    exts = {".js", ".ts", ".dart", ".json", ".md", ".ps1", ".patch"}
    for dirpath, dirnames, filenames in os.walk(root):
        # Skip heavy/vendor dirs
        dirnames[:] = [
            d
            for d in dirnames
            if d not in {"node_modules", ".git", "build", ".dart_tool", ".idea"}
        ]
        for name in filenames:
            p = Path(dirpath) / name
            if p.suffix.lower() in exts:
                yield p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True, help="Project root to scan")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    total_files = 0
    total_repls = 0

    for p in iter_target_files(root):
        count = process_file(p, args.dry_run)
        if count:
            total_files += 1
            total_repls += count
            print(f"{p}: fixed {count} run(s)")

    print(f"Done. Files changed: {total_files}, replacements: {total_repls}")


if __name__ == "__main__":
    main()
