#!/usr/bin/env python3
"""MELODY entry point for console.py of the tk4 plugin (TK4_HOME, default ~/claude-tk4).
Usage and settings: see the plugin script. Settings: MFHOST, MFUSER, MFPASS."""
import os
import runpy
import sys

home = os.environ.get("TK4_HOME", os.path.expanduser("~/claude-tk4"))
script = os.path.join(home, "scripts", "console.py")
if not os.path.exists(script):
    sys.exit("tk4 plugin not found at %s (set TK4_HOME)" % home)
runpy.run_path(script, run_name="__main__")
