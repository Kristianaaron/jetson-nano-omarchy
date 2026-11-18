#!/usr/bin/env bash
set -uo pipefail
WORKDIR=${1:-"$HOME/cuda-e0"}
REPORT_DIR=${2:-./results/cuda}
OUT="$WORKDIR/out"
REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TABLE="$REPO_ROOT/tools/cuda-e0/ioctl_table.py"
mkdir -p "$OUT" "$REPORT_DIR"

python3 "$TABLE" --label r32 --out "$OUT/r32.json" "$WORKDIR/src/r32-kernel/nvidia/nvgpu/include" "$WORKDIR/src/r32-kernel/nvidia/include"
python3 "$TABLE" --label r36 --out "$OUT/r36.json" "$WORKDIR/src/r36-nvgpu/include" "$WORKDIR/src/r36-nvgpu/drivers/gpu/nvgpu/include" "$WORKDIR/src/r36-nv-oot/include"
for label in r32 r36; do
  cmd="$OUT/$label.sizes.cmd"
  if bash "$cmd" > "$OUT/$label.sizes.txt" 2> "$OUT/$label.sizes.err"; then
    binary="${cmd%.cmd}"
    if [[ -x "$binary" ]]; then "$binary" >> "$OUT/$label.sizes.txt" 2>> "$OUT/$label.sizes.err" || true; fi
  fi
done
python3 - "$OUT/r32.json" "$OUT/r36.json" "$OUT/r32.sizes.txt" "$OUT/r36.sizes.txt" "$REPORT_DIR/E0a-ioctl-diff.md" <<'PY'
import json, pathlib, sys
r32, r36, s32, s36, target = map(pathlib.Path, sys.argv[1:])
a={x['name']:x for x in json.loads(r32.read_text())}; b={x['name']:x for x in json.loads(r36.read_text())}
def sizes(path):
 out={}
 if path.exists():
  for line in path.read_text(errors='replace').splitlines():
   fields=line.split()
   if len(fields)==2:
    try: out[fields[0]]=int(fields[1])
    except ValueError: pass
 return out
sa,sb=sizes(s32),sizes(s36)
same=[]; changed=[]; missing=[]; only=[]
for name,x in a.items():
 if name not in b:
  missing.append(name); continue
 y=b[name]; diffs=[]
 for field in ('dir','magic','nr'):
  if x[field] != y[field]: diffs.append((field,x[field],y[field]))
 if x['type'] and (name in sa or name in sb) and sa.get(name)!=sb.get(name): diffs.append(('size',sa.get(name,'unavailable'),sb.get(name,'unavailable')))
 if diffs: changed.append((name,diffs))
 else: same.append((name,x.get('header','unknown')))
only=sorted(set(b)-set(a))
lines=['# E0a ioctl comparison','', '| Result | Count |','|---|---:|',f'| SAME | {len(same)} |',f'| CHANGED | {len(changed)} |',f'| MISSING_IN_R36 | {len(missing)} |',f'| Only in R36 | {len(only)} |','', '## CHANGED','']
if changed:
 for name,diffs in changed:
  lines.append(f'- `{name}`: ' + '; '.join(f'{field}: R32 `{v1}`, R36 `{v2}`' for field,v1,v2 in diffs))
else: lines.append('- None.')
lines += ['', '## MISSING_IN_R36','']
lines += [f'- `{n}`' for n in missing] or ['- None.']
lines += ['', '## Only in R36','']
lines += [f'- `{n}`' for n in only] or ['- None.']
lines += ['', '## SAME, grouped by R32 header','']
by_header={}
for name,header in same: by_header.setdefault(header,[]).append(name)
for header,names in sorted(by_header.items()): lines.append(f'- `{header}`: ' + ', '.join(f'`{n}`' for n in names))
if not by_header: lines.append('- None.')
target.write_text('\n'.join(lines)+'\n')
PY

python3 - "$WORKDIR/src/libs" "$WORKDIR/src/package-versions.txt" "$REPORT_DIR/E0b-userspace-needs.md" <<'PY'
import os, pathlib, re, subprocess, sys
root=pathlib.Path(sys.argv[1]); versions={}
if pathlib.Path(sys.argv[2]).exists():
 for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
  p=line.split(maxsplit=1)
  if len(p)==2: versions[p[0]]=p[1]
files=[]
if root.exists():
 for p in root.rglob('*'):
  if p.is_file() and not p.is_symlink() and '.so' in p.name:
   try:
    ident=subprocess.run(['readelf','-h',str(p)],capture_output=True,text=True)
    if ident.returncode == 0 and 'ELF' in ident.stdout: files.append(p)
   except OSError: pass
focus=('libcuda.so','libnvrm_gpu.so','libnvrm_mem.so','libnvrm.so','libnvos.so','libnvrm_graphics_host.so')
def rank(p):
 return (0 if any(p.name.startswith(x) for x in focus) else 1, str(p).lower())
files.sort(key=rank)
rows=[]; allpaths=set()
for p in files:
 v=subprocess.run(['readelf','-V',str(p)],capture_output=True,text=True).stdout
 glibc=re.findall(r'GLIBC_(\d+(?:\.\d+)+)',v)
 highest=max(glibc,key=lambda x:tuple(map(int,x.split('.')))) if glibc else 'none found'
 dyn=subprocess.run(['readelf','-d',str(p)],capture_output=True,text=True).stdout
 needed=re.findall(r'\(NEEDED\).*?\[([^]]+)\]',dyn)
 strings=subprocess.run(['strings','-n','4',str(p)],capture_output=True,text=True).stdout.splitlines()
 paths=sorted(set(s for s in strings if re.match(r'^/(?:dev|sys|proc)/',s)))
 allpaths.update(paths)
 try: rel=p.relative_to(root).as_posix()
 except ValueError: rel=str(p)
 package=p.relative_to(root).parts[0]
 label=f'{package} {versions[package]}' if package in versions else package
 rows.append((rel,label,highest,needed,paths))
lines=['# E0b userspace needs','']
for rel,label,glibc,needed,paths in rows:
 lines += [f'## `{rel}`', '', f'- Package: `{label}`', f'- Highest GLIBC symbol version seen by `readelf -V`: `{glibc}`', '- NEEDED: ' + (', '.join(f'`{n}`' for n in needed) if needed else 'none found'), '- Paths:', '']
 lines += [f'  - `{p}`' for p in paths] or ['  - none found']
 lines.append('')
lines += ['## Combined unique paths','']
lines += [f'- `{p}`' for p in sorted(allpaths)] or ['- None found.']
pathlib.Path(sys.argv[3]).write_text('\n'.join(lines)+'\n')
PY

python3 - "$WORKDIR/src/libs" "$WORKDIR/src/package-versions.txt" "$OUT" "$REPORT_DIR/E0c-libcuda-maxwell.md" <<'PY'
import pathlib,re,subprocess,sys
root=pathlib.Path(sys.argv[1]); versions={}
if pathlib.Path(sys.argv[2]).exists():
 for l in pathlib.Path(sys.argv[2]).read_text().splitlines():
  p=l.split(maxsplit=1)
  if len(p)==2: versions[p[0]]=p[1]
sets=[('r32 cuda (control)','nvidia-l4t-cuda'),('r32 core (control)','nvidia-l4t-core'),('r35.6 cuda','r35.6-l4t-cuda'),('r35.6 core','r35.6-l4t-core'),('r36.4 cuda','r36.4-l4t-cuda'),('r36.4 core','r36.4-l4t-core'),('r36 cuda-compat','r36-cuda-compat')]
lines=['# E0c libcuda Maxwell markers','','The r32 rows are the control: in R32 the GM20B name lives in libnvrm_gpu.so (core), not libcuda. The method is valid only if a control row shows it.','','| Library | Package version | File size (bytes) | gm20b matches | gm20b_ matches | sm_53 | compute_53 | maxwell | 0xB1C0 bytes | 0xC7C0 bytes | 0xC3C0 bytes |','|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
for label,pkg in sets:
 d=root/('nvidia-l4t-cuda' if label.startswith('r32 ') else label)
 libs=[]
 if d.exists():
  libs=[p for p in d.rglob('*.so*') if p.is_file() and not p.is_symlink()]
 for p in sorted(libs):
  st=subprocess.run(['strings','-n','4',str(p)],capture_output=True,text=True).stdout
  counts=[len(re.findall(r'gm20b',st,re.I)),len(re.findall(r'gm20b_',st,re.I)),len(re.findall(r'sm_53',st,re.I)),len(re.findall(r'compute_53',st,re.I)),len(re.findall(r'maxwell',st,re.I))]
  data=p.read_bytes(); pats=[bytes.fromhex(x) for x in ('c0b10000','c0c70000','c0c30000')]
  bcounts=[data.count(x) for x in pats]
  version=versions.get(pkg,'not recorded')
  lines.append('| `'+'` | `'.join([label+'/'+p.relative_to(d).as_posix(),version,str(len(data)),*map(str,counts),*map(str,bcounts)])+'` |')
 if not libs:
  lines.append('| `'+'` | `'.join([label,'not found','0','n/a','n/a','n/a','n/a','n/a','n/a','n/a','n/a'])+'` |')
pathlib.Path(sys.argv[4]).write_text('\n'.join(lines)+'\n')
PY

mkdir -p "$OUT/e0d"
cat > "$OUT/e0d/k.cu" <<'CU'
extern "C" __global__ void axpy(float a, const float *x, float *y, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x; if (i < n) y[i] = a * x[i] + y[i]; }
CU
E0D="$REPORT_DIR/E0d-cubin.md"
: > "$E0D"
run_record() {
  local title=$1; shift
  local stdout="$OUT/e0d/command.stdout" stderr="$OUT/e0d/command.stderr" rc
  printf '\n## %s\n\nCommand: `%q' "$title" "$1" >> "$E0D"
  local arg
  for arg in "${@:2}"; do printf ' %q' "$arg" >> "$E0D"; done
  printf '`\n\n' >> "$E0D"
  "$@" > "$stdout" 2> "$stderr"; rc=$?
  COMMAND_RC=$rc
  printf 'Exit code: `%s`\n\n' "$rc" >> "$E0D"
  printf 'Stderr:\n\n```text\n' >> "$E0D"; cat "$stderr" >> "$E0D"; printf '\n```\n\nStdout:\n\n```text\n' >> "$E0D"; cat "$stdout" >> "$E0D"; printf '\n```\n' >> "$E0D"
  return 0
}
COMMAND_RC=0
CUDA12_CUBIN_RC=127
CUDA12_PTX_RC=127
find_one() { find "$1" -type f -name "$2" -perm -u+x -print -quit 2>/dev/null; }
NVCC12=$(find_one "$WORKDIR/src/cuda12" nvcc)
PTXAS10=$(find_one "$WORKDIR/src/cuda102" ptxas)
CUOBJDUMP10=$(find_one "$WORKDIR/src/cuda102" cuobjdump)
NVDISASM10=$(find_one "$WORKDIR/src/cuda102" nvdisasm)
NVCC10=$(find_one "$WORKDIR/src/cuda102" nvcc)
cd "$OUT/e0d"
rm -f k12.cubin k12.ptx k12-v63.ptx k102.cubin k102native.cubin
if [[ -n "$NVCC12" ]]; then
 run_record 'CUDA 12 sm_53 cubin build' "$NVCC12" -arch=sm_53 -cubin -o k12.cubin k.cu --allow-unsupported-compiler
 CUDA12_CUBIN_RC=$COMMAND_RC
 run_record 'CUDA 12 PTX build' "$NVCC12" -arch=compute_53 -ptx -o k12.ptx k.cu
 CUDA12_PTX_RC=$COMMAND_RC
 if [[ "$CUDA12_CUBIN_RC" -eq 0 && -f k12.cubin ]]; then
  run_record 'readelf header for CUDA 12 cubin' readelf -h k12.cubin
  run_record 'readelf sections for CUDA 12 cubin' readelf -S k12.cubin
 fi
 if [[ "$CUDA12_CUBIN_RC" -eq 0 && -f k12.cubin && -n "$CUOBJDUMP10" ]]; then run_record 'CUDA 10.2 cuobjdump on CUDA 12 cubin' "$CUOBJDUMP10" -sass k12.cubin; fi
 if [[ "$CUDA12_CUBIN_RC" -eq 0 && -f k12.cubin && -n "$NVDISASM10" ]]; then run_record 'CUDA 10.2 nvdisasm on CUDA 12 cubin' "$NVDISASM10" k12.cubin; fi
 if [[ "$CUDA12_PTX_RC" -eq 0 && -f k12.ptx && -n "$PTXAS10" ]]; then
  run_record 'Rewrite CUDA 12 PTX version to 6.5' bash -c 'sed -E "s/^\\.version[[:space:]]+[0-9]+\\.[0-9]+/.version 6.5/" k12.ptx > k12-v63.ptx'
  run_record 'CUDA 10.2 ptxas on CUDA 12 PTX rewritten to 6.5' "$PTXAS10" -arch=sm_53 -o k102.cubin k12-v63.ptx
  if [[ "$COMMAND_RC" -eq 0 && -f k102.cubin && -n "$CUOBJDUMP10" ]]; then run_record 'CUDA 10.2 cuobjdump on assembled PTX cubin' "$CUOBJDUMP10" -sass k102.cubin; fi
 fi
else echo 'CUDA 12 nvcc not found under WORKDIR/src/cuda12' >> "$E0D"; fi
if [[ -n "$NVCC10" ]]; then
 run_record 'CUDA 10.2 native sm_53 cubin build' "$NVCC10" -arch=sm_53 -cubin -o k102native.cubin k.cu
 NVCC10_RC=$COMMAND_RC
 if [[ "$NVCC10_RC" -eq 0 && -f k102native.cubin && "$CUDA12_CUBIN_RC" -eq 0 && -f k12.cubin ]]; then
  run_record 'readelf header diff of native CUDA 10.2 and CUDA 12 cubins' bash -c 'diff -u <(readelf -h k12.cubin) <(readelf -h k102native.cubin)'
 fi
else echo 'CUDA 10.2 nvcc not found under WORKDIR/src/cuda102' >> "$E0D"; fi
cd "$REPO_ROOT"
printf '%s\n' E0-OK
