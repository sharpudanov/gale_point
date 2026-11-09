#!/usr/bin/env bash
# Poly Haven (CC0) asset helper. API docs: https://polyhaven.com/llms.txt
#   tools/polyhaven.sh search <hdris|textures|models> "<query>"   -> top slugs + names
#   tools/polyhaven.sh info <slug>                                 -> name/type/tags/authors
#   tools/polyhaven.sh get <hdris|textures|models> <slug> [1k|2k]  -> downloads, imports, logs
# Files land in res://assets/<type>/<slug>/ ; each download is appended to ASSETS.md.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$PROJECT_ROOT"
UA="GalePoint-Dev/1.0"
API="https://api.polyhaven.com"
py() { PYTHONIOENCODING=utf-8 python -I -c "$1" "${@:2}" | tr -d '\015'; }   # JSON parsing (no jq); strip Windows CR

cmd="${1:-}"; shift || true
case "$cmd" in
search)
  type="${1:?type}"; q="${2:?query}"
  curl -sfG -A "$UA" "$API/search" --data-urlencode "q=$q" --data-urlencode "t=$type" | py '
import json,sys
d=json.load(sys.stdin)
ids=d if isinstance(d,list) else (d.get("results") or d.get("assets") or list(d))
for s in ids[:15]:
    print(s if isinstance(s,str) else "%s  (score %.2f)" % (s.get("slug"), s.get("score",0)))'
  ;;
info)
  slug="${1:?slug}"
  curl -sf -A "$UA" "$API/info/$slug" | py '
import json,sys
d=json.load(sys.stdin); t={0:"hdris",1:"textures",2:"models"}.get(d.get("type"),"?")
print("%s | type=%s | authors=%s | categories=%s | tags=%s" % (d["name"], t, ", ".join(d.get("authors",{})), ",".join(d.get("categories",[])), ",".join(d.get("tags",[])[:12])))'
  ;;
get)
  type="${1:?type}"; slug="${2:?slug}"; res="${3:-2k}"
  case "$res" in 1k|2k) ;; *) echo "resolution must be 1k or 2k" >&2; exit 1 ;; esac
  case "$type" in hdris|textures|models) ;; *) echo "type must be hdris|textures|models" >&2; exit 1 ;; esac
  dest="assets/$type/$slug"; mkdir -p "$dest"
  files_json="$(curl -sf -A "$UA" "$API/files/$slug")"
  info_json="$(curl -sf -A "$UA" "$API/info/$slug")"
  # Emit "relative_path<TAB>url<TAB>md5" lines for what we want.
  list="$(printf '%s' "$files_json" | py '
import json,sys
t,slug,res=sys.argv[1:4]; d=json.load(sys.stdin); out=[]
def add(name,f): out.append("\t".join([name, f["url"], f.get("md5","")]))
if t=="hdris":
    add("%s_%s.hdr" % (slug,res), d["hdri"][res]["hdr"])
elif t=="textures":
    want={"Diffuse":"jpg","nor_gl":"jpg","Rough":"jpg","AO":"jpg","arm":"jpg","Displacement":"png"}
    for m,fmt in want.items():
        if m in d and res in d[m] and fmt in d[m][res]:
            f=d[m][res][fmt]; add(f["url"].rsplit("/",1)[1], f)
else:
    g=d["gltf"][res]["gltf"]; add(g["url"].rsplit("/",1)[1], g)
    for rel,f in g.get("include",{}).items(): add(rel,f)
print("\n".join(out))' "$type" "$slug" "$res")"
  [ -z "$list" ] && { echo "nothing to download for $type/$slug@$res" >&2; exit 1; }
  while IFS=$'\t' read -r rel url md5; do
    mkdir -p "$dest/$(dirname "$rel")"
    curl -sfL -A "$UA" -o "$dest/$rel" "$url"
    if [ -n "$md5" ] && [ "$(md5sum "$dest/$rel" | cut -d' ' -f1)" != "$md5" ]; then
      echo "md5 mismatch: $dest/$rel" >&2; exit 1
    fi
  done <<< "$list"
  ensure_imported force    # generate .import files so Godot can load them
  authors="$(printf '%s' "$info_json" | py 'import json,sys; print(", ".join(json.load(sys.stdin).get("authors",{})))')"
  name="$(printf '%s' "$info_json" | py 'import json,sys; print(json.load(sys.stdin)["name"])')"
  [ -f ASSETS.md ] || printf '# Assets\n\n| Asset | Type | Res | Path | Source | Author(s) | License | Added |\n|---|---|---|---|---|---|---|---|\n' > ASSETS.md
  echo "| $name | $type | $res | res://$dest/ | https://polyhaven.com/a/$slug | $authors | CC0 | $(date +%F) |" >> ASSETS.md
  echo "downloaded to res://$dest/:"
  cut -f1 <<< "$list" | sed "s|^|  res://$dest/|"
  ;;
*)
  sed -n '2,7p' "$0"; exit 1 ;;
esac
