#!/usr/bin/env python3

import runpy
from os import scandir
from os.path import abspath, dirname

this_dir = dirname(abspath(__file__))


def filename(f):
    return f.name


with scandir(dirname(abspath(__file__))) as it:
    for f in sorted(it, key=filename):
        if f.name.startswith("__") or not f.is_file():
            continue

        print(f"▶️  Running the startup script {f.path}")
        try:
            runpy.run_path(f.path)
        except SystemExit as e:
            if e.code is not None and e.code != 0:
                print(
                    f"‼️ The startup script {f.path} returned with code {e.code}, exiting."
                )
                raise
