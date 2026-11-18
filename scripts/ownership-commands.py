#!/usr/bin/env python3
"""Emit debugfs commands that give the card's files their real owners and modes.

macOS stages the rootfs as the logged-in user (hdiutil ignores ownership), so
mke2fs -d writes every inode as 501:20 and drops setuid bits. This restores
uid, gid and permission bits from the Arch tarball for every path it ships.
Paths the builder added become root-owned, except the user's home.

Usage: ownership-commands.py TARBALL STAGING USER > cmds; debugfs -w -f cmds DEV
"""
import os
import stat
import sys
import tarfile


def key(path):
    path = os.path.normpath(path)
    return "/" if path == "." else "/" + path.lstrip("/")


def tar_index(path):
    index = {}
    with tarfile.open(path, "r:*") as tar:
        for m in tar:
            index[key(m.name)] = (m.uid, m.gid, m.mode & 0o7777)
    return index


def main():
    tarball, staging, user = sys.argv[1:4]
    home = f"/home/{user}"
    index = tar_index(tarball)
    out = sys.stdout
    skipped = 0
    paths = [staging]
    for dirpath, dirnames, filenames in os.walk(staging):
        paths += [os.path.join(dirpath, n) for n in dirnames + filenames]
    for entry in paths:
        rel = key(os.path.relpath(entry, staging))
        if '"' in rel or "\n" in rel:
            skipped += 1
            continue
        st = os.lstat(entry)
        if rel in index:
            uid, gid, perm = index[rel]
        elif rel == home or rel.startswith(home + "/"):
            uid, gid, perm = 1000, 1000, st.st_mode & 0o7777
        else:
            uid, gid, perm = 0, 0, st.st_mode & 0o7777
        q = f'"{rel}"'
        out.write(f"sif {q} uid {uid}\nsif {q} gid {gid}\n")
        if not stat.S_ISLNK(st.st_mode):
            out.write(f"sif {q} mode 0{stat.S_IFMT(st.st_mode) | perm:o}\n")
    if skipped:
        print(f"skipped {skipped} paths with quotes or newlines", file=sys.stderr)


if __name__ == "__main__":
    main()
