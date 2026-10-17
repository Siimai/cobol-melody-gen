#!/usr/bin/env python3
"""Record the MELPANEL demo session over a 3270 connection (s3270).

usage: record.py            (writes build/frames.json)

Environment (nothing is read from a file by this script):
  MFHOST  emulator host (default localhost; 172.17.0.1 in the dev container)
  MFUSER  TSO user to log on as (use a user the human is not using)
  MFPASS  that user's password

It logs on, starts MELPANEL, runs one melody, saves it, exports the MIDI,
lists the saved melodies, and always logs off. Every screen is stored as
text. The password is typed but never stored: the 3270 terminal does not
echo it, and the frame list is written before it is used again.
It never sends the password when the user ID is already in use.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "build", "frames.json")
SCALE, NOTES, TEMPO = "3", "12", "100"     # what is typed into the panel


class S3270:
    def __init__(self):
        self.p = subprocess.Popen(["s3270"], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, text=True, bufsize=1)

    def cmd(self, c):
        self.p.stdin.write(c + "\n")
        self.p.stdin.flush()
        out = []
        while True:
            line = self.p.stdout.readline()
            if not line or line.startswith("ok") or line.startswith("error"):
                break
            out.append(line.rstrip("\n"))
        return out

    def rows(self):
        return [l[6:].ljust(80)[:80] for l in self.cmd("Ascii") if l.startswith("data: ")]

    def cursor(self):
        for l in self.cmd("Query(Cursor)"):
            parts = l.split()
            if len(parts) == 3 and parts[0] == "data:":
                return [int(parts[1]), int(parts[2])]
        return [0, 0]

    def key(self, k, wait=1.5):
        self.cmd(k)
        time.sleep(wait)

    def txt(self, t):
        self.cmd('String("%s")' % t.replace('"', '\\"'))

    def last(self):
        r = [x.strip() for x in self.rows() if x.strip()]
        return r[-1] if r else ""


s = S3270()
frames = []


def snap(tag, kind="cut"):
    """kind 'type': the video animates the typing from the previous frame."""
    frames.append({"tag": tag, "kind": kind,
                   "rows": [r.rstrip() for r in s.rows()], "cursor": s.cursor()})
    print("--", tag, kind)


def ready():
    return s.last().startswith("READY")


def to_ready(tries=8):
    """Leave the welcome pages and the applications menu until READY shows."""
    for _ in range(tries):
        if ready():
            return True
        s.key("Enter" if "***" in s.last() else "PF(3)", 2)
    return ready()


def wait_change(before, secs=20):
    for _ in range(secs * 2):
        time.sleep(0.5)
        if s.rows() != before:
            time.sleep(1)
            return True
    return False


def step(key, tag, secs):
    before = s.rows()
    s.key(key, 1)
    wait_change(before, secs)
    snap(tag)


def main():
    host = os.environ.get("MFHOST", "localhost")
    user = os.environ.get("MFUSER")
    pw = os.environ.get("MFPASS")
    if not user or not pw:
        sys.exit("set MFUSER and MFPASS (see mvs/demo/README.md)")
    logged_on = False
    try:
        s.cmd("Connect(%s:3270)" % host)
        time.sleep(2)
        snap("vtam")
        s.txt("L " + user)
        snap("vtam-typed", "type")
        s.key("Enter", 2)
        snap("pw-prompt")
        scr = "\n".join(s.rows())
        if "IN USE" in scr:
            sys.exit("%s is already logged on (IN USE); nothing was sent" % user)
        if "PASSWORD" not in scr:
            sys.exit("unexpected logon screen:\n" + scr)
        logged_on = True
        s.txt(pw)                      # never snapshotted
        s.key("Enter", 3)
        snap("welcome")
        if not to_ready():
            sys.exit("never reached READY")
        snap("ready")
        s.txt("MELPANEL")
        snap("melpanel-typed", "type")
        s.key("Enter", 5)
        snap("panel")
        if "MELODY68" not in "\n".join(s.rows()):
            sys.exit("the panel did not start")
        s.txt(SCALE); s.key("Tab", .3)
        s.txt(NOTES); s.key("Tab", .3)
        s.txt(TEMPO)
        snap("filled", "type")
        step("Enter", "run1", 20)
        step("PF(5)", "save", 8)
        step("PF(7)", "midi", 12)
        step("PF(6)", "list", 8)
    finally:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        with open(OUT, "w") as f:
            json.dump({"user": user, "frames": frames}, f)
        try:
            if logged_on:
                if to_ready():
                    s.txt("LOGOFF")
                    s.key("Enter", 3)
                else:
                    print("!!! could not reach READY: %s is probably stuck IN USE "
                          "(cancel it from the console: /C U=%s)" % (user, user),
                          file=sys.stderr)
            s.cmd("Disconnect")
            s.cmd("Quit")
        except Exception:
            pass


if __name__ == "__main__":
    main()
