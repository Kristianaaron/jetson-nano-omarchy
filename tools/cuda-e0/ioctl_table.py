#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path

DEFINE_RE = re.compile(r'^\s*#\s*define\s+(\w+)\s+(.+)$')
IOCTL_RE = re.compile(r'^\s*#\s*define\s+(\w+)\s+_(IO|IOR|IOW|IOWR)\s*\(\s*([^,]+)\s*,\s*([^,)]+)(?:\s*,\s*(.*?))?\s*\)\s*$', re.S)
LITERAL_RE = re.compile(r"^(?:'((?:\\.|[^'])*)'|([-+]?(?:0[xX][0-9a-fA-F]+|0[0-7]*|[1-9][0-9]*)))$")


def logical_lines(path):
    pending = ''
    for line in path.read_text(errors='replace').splitlines():
        line = line.rstrip()
        if pending:
            pending += line.lstrip()
        else:
            pending = line
        if pending.endswith('\\'):
            pending = pending[:-1] + ' '
            continue
        yield pending
        pending = ''
    if pending:
        yield pending


def c_int(text):
    text = text.strip()
    match = LITERAL_RE.match(text)
    if not match:
        return None
    if match.group(1) is not None:
        value = match.group(1)
        if value.startswith('\\'):
            escapes = {'\\n': '\n', '\\r': '\r', '\\t': '\t', "\\'": "'", '\\\\': '\\', '\\0': '\0'}
            value = escapes.get(value, value[1:])
        return ord(value[0]) if value else 0
    number = match.group(2)
    return int(number, 16 if number.lower().startswith('0x') else 8 if len(number) > 1 and number.startswith('0') else 10)


def resolve(text, defines):
    text = text.strip()
    seen = set()
    while text in defines and text not in seen:
        seen.add(text)
        text = defines[text].strip()
    return c_int(text) if c_int(text) is not None else text


def type_name(raw):
    raw = (raw or '').strip()
    match = re.search(r'\bstruct\s+([A-Za-z_]\w*)', raw)
    return match.group(1) if match else ''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--label', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('header_dirs', nargs='+')
    args = parser.parse_args()
    roots = [Path(p).resolve() for p in args.header_dirs]
    scanned = []
    for root in roots:
        if root.is_dir():
            scanned.extend(p for p in root.rglob('*.h') if re.match(r'^(?:nvgpu|nvmap|nvhost).*\.h$', p.name, re.I))
    scanned = sorted(set(scanned))
    defines = {}
    lines_by_file = {}
    for path in scanned:
        lines = list(logical_lines(path))
        lines_by_file[path] = lines
        for line in lines:
            match = DEFINE_RE.match(line)
            if match:
                defines.setdefault(match.group(1), match.group(2).strip())
    entries = []
    for path in scanned:
        root = next((r for r in roots if path == r or r in path.parents), path.parent)
        for line in lines_by_file[path]:
            match = IOCTL_RE.match(line)
            if not match:
                continue
            name, op, magic, nr, raw_type = match.groups()
            entries.append({
                'name': name,
                'dir': {'IO': 'none', 'IOR': 'r', 'IOW': 'w', 'IOWR': 'rw'}[op],
                'magic': resolve(magic, defines),
                'nr': resolve(nr, defines),
                'type': type_name(raw_type),
                'header': path.relative_to(root).as_posix(),
            })
    entries.sort(key=lambda e: (e['name'], e['header']))
    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(entries, indent=2) + '\n')
    include_dirs = []
    for root in roots:
        for candidate in (root, root / 'include', root / 'uapi', root / 'include/uapi'):
            if candidate.is_dir() and candidate not in include_dirs:
                include_dirs.append(candidate)
    c_path = Path(str(out)[:-5] + '.sizes.c') if str(out).endswith('.json') else Path(str(out) + '.sizes.c')
    cmd_path = Path(str(c_path)[:-2] + '.cmd')
    relative_headers = []
    for path in scanned:
        root = next((r for r in roots if path == r or r in path.parents), path.parent)
        relative_headers.append((root, path.relative_to(root).as_posix()))
    lines = ['/* gcc include paths: ' + ' '.join('-I' + str(p) for p in include_dirs) + ' */']
    lines.extend('#include <' + h + '>' for _, h in relative_headers)
    lines += ['#include <stdio.h>', 'int main(void) {']
    for entry in entries:
        if entry['type']:
            lines += [f'#ifdef {entry["name"]}', f'    printf("%s %zu\\n", "{entry["name"]}", sizeof(struct {entry["type"]}));', '#endif']
    lines += ['    return 0;', '}']
    c_path.write_text('\n'.join(lines) + '\n')
    command = ['gcc'] + ['-I' + str(p) for p in include_dirs] + [str(c_path), '-o', str(c_path.with_suffix(''))]
    import shlex
    cmd_path.write_text(shlex.join(command) + '\n')


if __name__ == '__main__':
    main()
