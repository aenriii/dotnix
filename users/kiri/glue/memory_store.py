#!/usr/bin/env python3
"""
memory_store.py — Kiri's semantic memory system.

Fragments are stored as text files in ~/memory/fragments/
Embeddings live in a FAISS index at ~/memory/fragments.index (+ .pkl for metadata)

Usage:
  memory_store.py write  "fragment text"  [--tags tag1,tag2]
  memory_store.py retrieve "query text"  [--top-k 5]
  memory_store.py rebuild   # re-embed all fragments from scratch
  memory_store.py list      # list all fragment files
"""

import argparse
import os
import pickle
import sys
import textwrap
from datetime import datetime
from pathlib import Path

FRAGMENTS_DIR = Path.home() / "memory" / "fragments"
INDEX_PATH = Path.home() / "memory" / "fragments.index"
META_PATH  = Path.home() / "memory" / "fragments.meta.pkl"
MODEL_NAME = "nomic-ai/nomic-embed-text-v1"

FRAGMENTS_DIR.mkdir(parents=True, exist_ok=True)


# ── lazy imports (only load heavy deps when needed) ──────────────────────────

def _load_model():
    import os
    os.environ["CUDA_VISIBLE_DEVICES"] = ""  # force CPU — 1050 Ti is incompatible with installed torch
    from sentence_transformers import SentenceTransformer
    # trust_remote_code needed for nomic-embed-text
    return SentenceTransformer(MODEL_NAME, trust_remote_code=True, device="cpu")


def _load_faiss():
    import faiss
    return faiss


# ── index helpers ─────────────────────────────────────────────────────────────

def _load_index():
    """Load the FAISS index + metadata, or return empty state."""
    faiss = _load_faiss()
    if INDEX_PATH.exists() and META_PATH.exists():
        index = faiss.read_index(str(INDEX_PATH))
        with open(META_PATH, "rb") as f:
            meta = pickle.load(f)
    else:
        # 768-dim for nomic-embed-text
        index = faiss.IndexFlatIP(768)  # inner product (cosine after norm)
        meta = []  # list of {path, text, tags, created}
    return index, meta


def _save_index(index, meta):
    faiss = _load_faiss()
    faiss.write_index(index, str(INDEX_PATH))
    with open(META_PATH, "wb") as f:
        pickle.dump(meta, f)


def _embed(model, texts):
    import numpy as np
    vecs = model.encode(
        texts,
        normalize_embeddings=True,
        show_progress_bar=False,
        prompt_name="document",
    )
    return vecs.astype("float32")


# ── commands ──────────────────────────────────────────────────────────────────

def cmd_write(text: str, tags: list[str]):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    fname = f"{timestamp}.md"
    fpath = FRAGMENTS_DIR / fname

    tag_line = f"tags: {', '.join(tags)}\n" if tags else ""
    content = f"---\ncreated: {datetime.now().isoformat()}\n{tag_line}---\n\n{text}\n"
    fpath.write_text(content)

    # Embed and add to index
    model = _load_model()
    index, meta = _load_index()
    vec = _embed(model, [text])
    index.add(vec)
    meta.append({"path": str(fpath), "text": text, "tags": tags, "created": timestamp})
    _save_index(index, meta)

    print(f"saved: {fname}")


def cmd_retrieve(query: str, top_k: int):
    index, meta = _load_index()
    if index.ntotal == 0:
        print("(no memories yet)")
        return

    model = _load_model()
    import numpy as np
    vec = model.encode(
        [query],
        normalize_embeddings=True,
        show_progress_bar=False,
        prompt_name="query",
    ).astype("float32")

    k = min(top_k, index.ntotal)
    scores, idxs = index.search(vec, k)

    results = []
    for score, idx in zip(scores[0], idxs[0]):
        if idx < 0:
            continue
        entry = meta[idx]
        results.append((float(score), entry))

    # Output as a block for injection into the prompt
    if not results:
        print("(no relevant memories found)")
        return

    parts = []
    for score, entry in results:
        ts = entry.get("created", "")
        tags = entry.get("tags", [])
        tag_str = f" [{', '.join(tags)}]" if tags else ""
        parts.append(f"[{ts}{tag_str} | relevance {score:.2f}]\n{entry['text']}")

    print("\n\n".join(parts))


def cmd_rebuild():
    """Re-embed all fragment files from scratch."""
    faiss = _load_faiss()
    index = faiss.IndexFlatIP(768)
    meta = []

    files = sorted(FRAGMENTS_DIR.glob("*.md"))
    if not files:
        print("no fragments to rebuild")
        return

    model = _load_model()
    texts = []
    entries = []

    for fpath in files:
        raw = fpath.read_text()
        # Strip frontmatter
        lines = raw.split("\n")
        in_front = False
        body_lines = []
        front_done = False
        for line in lines:
            if line.strip() == "---" and not front_done:
                if not in_front:
                    in_front = True
                else:
                    front_done = True
                continue
            if front_done:
                body_lines.append(line)
        text = "\n".join(body_lines).strip()
        if not text:
            continue
        texts.append(text)
        entries.append({"path": str(fpath), "text": text, "tags": [], "created": fpath.stem})

    if not texts:
        print("no text content found in fragments")
        return

    vecs = _embed(model, texts)
    index.add(vecs)
    meta.extend(entries)
    _save_index(index, meta)
    print(f"rebuilt index with {len(texts)} fragments")


def cmd_list():
    files = sorted(FRAGMENTS_DIR.glob("*.md"))
    if not files:
        print("no fragments yet")
        return
    for f in files:
        print(f.name)


# ── entrypoint ────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Kiri's semantic memory store")
    sub = parser.add_subparsers(dest="cmd")

    p_write = sub.add_parser("write")
    p_write.add_argument("text")
    p_write.add_argument("--tags", default="")

    p_retrieve = sub.add_parser("retrieve")
    p_retrieve.add_argument("query")
    p_retrieve.add_argument("--top-k", type=int, default=5)

    sub.add_parser("rebuild")
    sub.add_parser("list")

    args = parser.parse_args()

    if args.cmd == "write":
        tags = [t.strip() for t in args.tags.split(",") if t.strip()]
        cmd_write(args.text, tags)
    elif args.cmd == "retrieve":
        cmd_retrieve(args.query, args.top_k)
    elif args.cmd == "rebuild":
        cmd_rebuild()
    elif args.cmd == "list":
        cmd_list()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
