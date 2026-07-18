from __future__ import annotations

import os
import subprocess
import sys
from importlib.resources import files


def main() -> int:
    script = files("tokenbar").joinpath("tokenbar")
    return subprocess.call([str(script), *sys.argv[1:]], env=os.environ.copy())


if __name__ == "__main__":
    raise SystemExit(main())
