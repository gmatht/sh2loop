#!/usr/bin/env python3
# profile-merge.py — merge SH2_PROFILE=1 JSON outputs.
#
# Each transpiled-C run dumps one profile JSON (schema 1): per-site loop
# trips, branch-arm counts, value-magnitude buckets, array lengths. This
# tool validates, checks staleness (source_hash), and merges N runs of
# the SAME program into one report:
#   loops:    trips concat (truncate 64, first-file-wins), execs/trip_sum
#             sum, trip_max max
#   branches: execs sum
#   mags:     max_bucket max
#   lens:     len_max max, appends sum
# Sites zip by index with a name-equality check — same source_hash means
# same layout, so a name mismatch is a hard error, never a silent merge.
#
# Usage:
#   profile-merge.py a.json b.json [--out merged.json]
#   profile-merge.py --self-test
import json
import sys

SCHEMA = 1
TRIPS_CAP = 64


def load(path):
    with open(path) as f:
        d = json.load(f)
    if d.get("schema") != SCHEMA:
        raise SystemExit(f"{path}: unsupported schema {d.get('schema')!r} (want {SCHEMA})")
    for k in ("source_hash", "options", "loops", "branches", "mags", "lens"):
        if k not in d:
            raise SystemExit(f"{path}: missing key {k!r}")
    return d


def merge_sites(kind, acc, new, path):
    if len(acc) != len(new):
        raise SystemExit(
            f"{path}: {kind} site count {len(new)} != {len(acc)} — layout changed, refusing merge"
        )
    for i, (a, b) in enumerate(zip(acc, new)):
        if a["name"] != b["name"]:
            raise SystemExit(
                f"{path}: {kind}[{i}] name {b['name']!r} != {a['name']!r} — refusing merge"
            )
        if kind == "loops":
            a["trips"] = (a["trips"] + b["trips"])[:TRIPS_CAP]
            a["execs"] += b["execs"]
            a["trip_sum"] += b["trip_sum"]
            a["trip_max"] = max(a["trip_max"], b["trip_max"])
        elif kind == "branches":
            a["execs"] += b["execs"]
        elif kind == "mags":
            a["max_bucket"] = max(a["max_bucket"], b["max_bucket"])
        elif kind == "lens":
            a["len_max"] = max(a["len_max"], b["len_max"])
            a["appends"] += b["appends"]


def merge(docs):
    base = docs[0]
    h = base["source_hash"]
    for d in docs[1:]:
        if d["source_hash"] != h:
            raise SystemExit(
                f"source_hash {d['source_hash']!r} != {h!r} — profiles are from "
                "different sources/flags, refusing merge"
            )
    opts = [d["options"] for d in docs]
    if any(o != opts[0] for o in opts[1:]):
        print("warning: options differ between runs — merged anyway", file=sys.stderr)
    out = {
        "schema": SCHEMA,
        "hash_algo": base.get("hash_algo", "fnv1a64"),
        "source_hash": h,
        "options": opts[0],
        "loops": [dict(s, trips=list(s["trips"])) for s in base["loops"]],
        "branches": [dict(s) for s in base["branches"]],
        "mags": [dict(s) for s in base["mags"]],
        "lens": [dict(s) for s in base["lens"]],
    }
    # (source paths are informational only — not merged)
    for d, path in zip(docs[1:], paths[1:]):
        for kind in ("loops", "branches", "mags", "lens"):
            merge_sites(kind, out[kind], d[kind], path)
    return out


def self_test():
    a = {
        "schema": 1, "hash_algo": "fnv1a64", "source_hash": "aa",
        "options": {"target": "c"},
        "loops": [{"name": "main:while@0", "trips": [5], "execs": 1, "trip_sum": 5, "trip_max": 5}],
        "branches": [{"name": "main:if0/then@0", "execs": 3}],
        "mags": [{"name": "main:mag:i@0", "max_bucket": 1}],
        "lens": [{"name": "main:len:xs@0", "len_max": 5, "appends": 3}],
    }
    b = {
        "schema": 1, "hash_algo": "fnv1a64", "source_hash": "aa",
        "options": {"target": "c"},
        "loops": [{"name": "main:while@0", "trips": [7], "execs": 1, "trip_sum": 7, "trip_max": 7}],
        "branches": [{"name": "main:if0/then@0", "execs": 4}],
        "mags": [{"name": "main:mag:i@0", "max_bucket": 2}],
        "lens": [{"name": "main:len:xs@0", "len_max": 6, "appends": 4}],
    }
    global paths
    paths = ["a", "b"]
    m = merge([a, b])
    assert m["loops"][0]["trips"] == [5, 7], m
    assert m["loops"][0]["execs"] == 2
    assert m["loops"][0]["trip_sum"] == 12
    assert m["loops"][0]["trip_max"] == 7
    assert m["branches"][0]["execs"] == 7
    assert m["mags"][0]["max_bucket"] == 2
    assert m["lens"][0]["len_max"] == 6
    assert m["lens"][0]["appends"] == 7
    # trips truncation: first-file-wins past 64
    big = dict(a)
    big["loops"] = [dict(a["loops"][0], trips=list(range(64)))]
    paths = ["a", "b"]
    m2 = merge([big, b])
    assert m2["loops"][0]["trips"] == list(range(64)), m2["loops"][0]["trips"][-3:]
    # staleness refusal
    c = dict(b, source_hash="bb")
    try:
        merge([a, c])
    except SystemExit as e:
        assert "refusing merge" in str(e), e
    else:
        raise AssertionError("hash mismatch merged!")
    # layout refusal
    d = dict(b)
    d["loops"] = d["loops"] + [dict(d["loops"][0], name="main:while@1")]
    try:
        merge([a, d])
    except SystemExit as e:
        assert "refusing merge" in str(e), e
    else:
        raise AssertionError("layout mismatch merged!")
    print("profile-merge self-test: OK")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--self-test"]:
        self_test()
        sys.exit(0)
    paths = []
    out_path = None
    rest = []
    it = iter(args)
    for a in it:
        if a == "--out":
            out_path = next(it, None)
            if out_path is None:
                raise SystemExit("--out needs a path")
        else:
            rest.append(a)
    paths = rest
    if not paths:
        raise SystemExit("usage: profile-merge.py a.json [b.json ...] [--out merged.json]")
    docs = [load(p) for p in paths]
    merged = merge(docs)
    text = json.dumps(merged, indent=2) + "\n"
    if out_path:
        with open(out_path, "w") as f:
            f.write(text)
    else:
        sys.stdout.write(text)
