#!/usr/bin/env bash
set -euo pipefail
WORKDIR=${1:-"$HOME/cuda-e0"}
SRC="$WORKDIR/src"
mkdir -p "$SRC/debs" "$SRC/libs" "$SRC/cuda12" "$SRC/cuda102"

clone_sparse() {
  local url=$1 branch=$2 dest=$3
  shift 3
  if [[ ! -d "$dest/.git" ]]; then
    git clone --depth 1 --filter=blob:none --sparse --branch "$branch" "$url" "$dest"
  fi
  git -C "$dest" sparse-checkout set "$@"
}
clone_sparse https://github.com/OE4T/linux-tegra-4.9 oe4t-patches-l4t-r32.7.4 "$SRC/r32-kernel" nvidia/nvgpu/include nvidia/include/uapi nvidia/include/linux include/uapi/linux
clone_sparse https://github.com/OE4T/linux-nvgpu patches-rel-36 "$SRC/r36-nvgpu" include drivers/gpu/nvgpu/include
clone_sparse https://github.com/OE4T/linux-nv-oot patches-rel-36 "$SRC/r36-nv-oot" include drivers/video/tegra/nvmap

fetch_packages() {
  local base=$1 destination=$2 url=$3
  if [[ ! -s "$destination" ]]; then
    if ! curl -fL "$url" -o "$destination"; then
      curl -fL "$url.gz" -o "$destination.gz"
      gzip -dc "$destination.gz" > "$destination"
    fi
  fi
}
fetch_packages "$SRC" "$SRC/Packages-t210" https://repo.download.nvidia.com/jetson/t210/dists/r32.7/main/binary-arm64/Packages

select_package() {
  python3 - "$1" "$2" <<'PY'
import re, sys
path, package = sys.argv[1:]
entries = []
for block in open(path, errors='replace').read().split('\n\n'):
    fields = {}
    for line in block.splitlines():
        if line and not line[0].isspace() and ': ' in line:
            key, value = line.split(': ', 1)
            fields[key] = value
    if fields.get('Package') == package and fields.get('Filename') and fields.get('SHA256'):
        entries.append((fields.get('Version', ''), fields['Filename'], fields['SHA256']))
def version_key(value):
    epoch, sep, rest = value.partition(':')
    if sep:
        value = rest
    else:
        epoch = '0'
    upstream, _, revision = value.rpartition('-')
    if not revision:
        upstream, revision = value, '0'
    def parts(s):
        return tuple((0, int(x)) if x.isdigit() else (1, x.lower()) for x in re.findall(r'\d+|\D+', s))
    return (int(epoch or 0), parts(upstream), parts(revision))
if entries:
    print('\t'.join(max(entries, key=lambda x: version_key(x[0]))))
PY
}
extract_deb() {
  local package=$1 label=$2 filename=$3 sha=$4 base=$5
  local deb="$SRC/debs/$(basename "$filename")"
  if [[ ! -s "$deb" ]]; then curl -fL "$base/$filename" -o "$deb"; fi
  printf '%s  %s\n' "$sha" "$deb" | sha256sum -c -
  local dest="$SRC/libs/$label"
  if [[ ! -f "$dest/.e0-extracted" ]]; then
    mkdir -p "$dest"
    local tmp
    tmp=$(mktemp -d "$SRC/debs/extract.XXXXXX")
    bsdtar -xf "$deb" -C "$tmp" 'data.tar.*'
    local data=("$tmp"/data.tar.*)
    bsdtar -xf "${data[0]}" -C "$dest"
    touch "$dest/.e0-extracted"
    rm -rf "$tmp"
  fi
}
get_package() {
  local package=$1 label=$2 packages=$3 base=$4
  local selected
  selected=$(select_package "$packages" "$package")
  if [[ -z "$selected" ]]; then return 1; fi
  IFS=$'\t' read -r version filename sha <<< "$selected"
  extract_deb "$package" "$label" "$filename" "$sha" "$base"
  printf '%s %s\n' "$label" "$version" >> "$SRC/package-versions.txt"
  printf '%s %s\n' "$label" "$version"
}
: > "$SRC/package-versions.txt"
get_package nvidia-l4t-cuda nvidia-l4t-cuda "$SRC/Packages-t210" https://repo.download.nvidia.com/jetson/t210 || { echo 'missing package nvidia-l4t-cuda' >&2; exit 1; }
get_package nvidia-l4t-core nvidia-l4t-core "$SRC/Packages-t210" https://repo.download.nvidia.com/jetson/t210 || { echo 'missing package nvidia-l4t-core' >&2; exit 1; }

fetch_dist_package() {
  local name=$1 label=$2 packages=$3 base=$4
  get_package "$name" "$label" "$packages" "$base" || { echo "missing package $name in $packages"; return 0; }
}
for rel in r36.4 r35.6; do
  path="$SRC/Packages-t234-$rel"
  if [[ ! -s "$path" ]]; then
    if ! curl -fL "https://repo.download.nvidia.com/jetson/t234/dists/$rel/main/binary-arm64/Packages" -o "$path"; then
      if ! curl -fL "https://repo.download.nvidia.com/jetson/t234/dists/$rel/main/binary-arm64/Packages.gz" -o "$path.gz"; then
        echo "unavailable t234 $rel"
        continue
      fi
      gzip -dc "$path.gz" > "$path"
    fi
  fi
  fetch_dist_package nvidia-l4t-cuda "$rel-l4t-cuda" "$path" https://repo.download.nvidia.com/jetson/t234
  fetch_dist_package nvidia-l4t-core "$rel-l4t-core" "$path" https://repo.download.nvidia.com/jetson/t234
 done
common="$SRC/Packages-common-r36.4"
if [[ -s "$common" ]] || curl -fL https://repo.download.nvidia.com/jetson/common/dists/r36.4/main/binary-arm64/Packages -o "$common" || curl -fL https://repo.download.nvidia.com/jetson/common/dists/r36.4/main/binary-arm64/Packages.gz -o "$common.gz"; then
  if [[ ! -s "$common" ]]; then gzip -dc "$common.gz" > "$common"; fi
  compat=$(python3 - "$common" <<'PY'
import re, sys
path=sys.argv[1]
items=[]
for block in open(path, errors='replace').read().split('\n\n'):
 d={}
 for line in block.splitlines():
  if line and not line[0].isspace() and ': ' in line:
   k,v=line.split(': ',1); d[k]=v
 if re.match(r'^cuda-compat-orin-12-',d.get('Package','')) and d.get('Filename') and d.get('SHA256'):
  items.append((d.get('Version',''),d['Package']))
def key(value):
 epoch,colon,rest=value.partition(':')
 if colon: value=rest
 else: epoch='0'
 upstream,sep,revision=value.rpartition('-')
 if not sep: upstream,revision=value,'0'
 def parts(text): return tuple((0,int(x)) if x.isdigit() else (1,x.lower()) for x in re.findall(r'\d+|\D+',text))
 return int(epoch or 0),parts(upstream),parts(revision)
print('\t'.join(max(items,key=lambda item:key(item[0])) if items else ('','')))
PY
)
  IFS=$'\t' read -r compat_version compat_name <<< "$compat"
  if [[ -n "$compat_name" ]]; then fetch_dist_package "$compat_name" r36-cuda-compat "$common" https://repo.download.nvidia.com/jetson/common; else echo 'no cuda-compat-orin-12-* package in common r36.4'; fi
else echo 'unavailable jetson common r36.4'; fi

redist="$SRC/redistrib_12.6.3.json"
if [[ ! -s "$redist" ]]; then curl -fL https://developer.download.nvidia.com/compute/cuda/redist/redistrib_12.6.3.json -o "$redist"; fi
python3 - "$redist" "$SRC/cuda12" <<'PY'
import hashlib, json, os, pathlib, sys, tarfile, urllib.request
manifest=json.load(open(sys.argv[1])); root=pathlib.Path(sys.argv[2]); base='https://developer.download.nvidia.com/compute/cuda/redist/'
for pkg in ('cuda_nvcc','cuda_cuobjdump','cuda_nvdisasm','cuda_cudart'):
 entry=manifest.get(pkg) or manifest.get('packages',{}).get(pkg,{})
 variants=entry.get('linux-sbsa') or entry.get('supported',{}).get('linux-sbsa') or []
 if isinstance(variants,dict): variants=[variants]
 if not variants:
  print('missing linux-sbsa',pkg); continue
 item=variants[0]; rel=item['relative_path']; sha=item['sha256']; archive=root/pathlib.Path(rel).name
 if not archive.exists(): urllib.request.urlretrieve(base+rel,archive)
 digest=hashlib.sha256(archive.read_bytes()).hexdigest()
 if digest != sha: raise SystemExit(f'sha256 mismatch {archive}: {digest} != {sha}')
 target=root/pkg
 marker=target/'.e0-extracted'
 if not marker.exists():
  target.mkdir(parents=True,exist_ok=True)
  with tarfile.open(archive,'r:xz') as tf: tf.extractall(target)
  marker.touch()
 print(pkg,rel,sha)
PY

fetch_packages "$SRC" "$SRC/Packages-common-r32.7" https://repo.download.nvidia.com/jetson/common/dists/r32.7/main/binary-arm64/Packages
for package in cuda-nvcc-10-2 cuda-cuobjdump-10-2 cuda-nvdisasm-10-2; do
  selected=$(select_package "$SRC/Packages-common-r32.7" "$package")
  if [[ -n "$selected" ]]; then
    IFS=$'\t' read -r version filename sha <<< "$selected"
    deb="$SRC/debs/$(basename "$filename")"
    [[ -s "$deb" ]] || curl -fL "https://repo.download.nvidia.com/jetson/common/$filename" -o "$deb"
    printf '%s  %s\n' "$sha" "$deb" | sha256sum -c -
    dest="$SRC/cuda102/$package"
    if [[ ! -f "$dest/.e0-extracted" ]]; then
      mkdir -p "$dest"
      tmp=$(mktemp -d "$SRC/debs/extract.XXXXXX")
      bsdtar -xf "$deb" -C "$tmp" 'data.tar.*'
      data=("$tmp"/data.tar.*)
      bsdtar -xf "${data[0]}" -C "$dest"
      touch "$dest/.e0-extracted"
      rm -rf "$tmp"
    fi
    printf '%s %s\n' "$package" "$version" >> "$SRC/package-versions.txt"
    printf '%s %s\n' "$package" "$version"
  else
    mkdir -p "$WORKDIR/out"
    awk -F': ' '/^Package: cuda-.*-10-2$/ {print $2}' "$SRC/Packages-t210" > "$WORKDIR/out/cuda102-packages.txt"
    echo "missing package $package"
  fi
done
printf '%s\n' FETCH-OK
