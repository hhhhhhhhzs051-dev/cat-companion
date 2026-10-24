"""Atomically install a verified bundle on macOS; caller archives previous version."""
import ctypes
import os
import sys
from pathlib import Path
source, target = map(Path, sys.argv[1:])
if target.exists():
    libc = ctypes.CDLL(None, use_errno=True)
    swap = libc.renameatx_np
    swap.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    swap.restype = ctypes.c_int
    if swap(-2, os.fsencode(source), -2, os.fsencode(target), 2) != 0:
        raise OSError(ctypes.get_errno(), 'Atomic bundle swap failed; existing app retained')
else:
    os.rename(source, target)
