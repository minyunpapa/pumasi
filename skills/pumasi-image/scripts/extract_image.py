#!/usr/bin/env python3
"""Extract the generated image from `codex exec --json` output (or a session rollout).

codex exec generates images via the `image_generation_call` tool but, unlike the
interactive TUI, does NOT persist them to ~/.codex/generated_images/. The PNG is
returned inline as base64 in the `result` field of `image_generation_call` /
`image_generation_end` events. This decodes that base64 and writes the PNG.

Usage: extract_image.py <source_jsonl> <target_png>
Exit:  0 = wrote target, 1 = no image found, 2 = usage error
"""
import sys, json, base64

def find_results(obj, out):
    """Collect base64 PNG result strings from image_generation events."""
    if isinstance(obj, dict):
        t = obj.get("type")
        if t in ("image_generation_call", "image_generation_end"):
            r = obj.get("result")
            if isinstance(r, str) and r.startswith("iVBOR"):  # PNG magic in base64
                out.append((obj.get("id") or obj.get("call_id") or "", r))
        for v in obj.values():
            find_results(v, out)
    elif isinstance(obj, list):
        for v in obj:
            find_results(v, out)

def main():
    if len(sys.argv) != 3:
        print("usage: extract_image.py <source_jsonl> <target_png>", file=sys.stderr)
        return 2
    src, target = sys.argv[1], sys.argv[2]
    results = []
    try:
        with open(src, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                find_results(obj, results)
    except OSError as e:
        print(f"cannot read {src}: {e}", file=sys.stderr)
        return 1
    if not results:
        return 1
    # Prefer the largest payload (the final full image, not a progressive/partial frame).
    _id, b64 = max(results, key=lambda kv: len(kv[1]))
    try:
        raw = base64.b64decode(b64)
    except Exception as e:
        print(f"base64 decode failed: {e}", file=sys.stderr)
        return 1
    if not raw.startswith(b"\x89PNG"):
        print("decoded bytes are not a PNG", file=sys.stderr)
        return 1
    with open(target, "wb") as out:
        out.write(raw)
    print(f"wrote {len(raw)} bytes to {target} (call_id={_id})")
    return 0

if __name__ == "__main__":
    sys.exit(main())
