#!/usr/bin/env python3
"""Print a TSO data set (or member) read over a 3270 session with s3270.

usage: tso-list.py 'DATA.SET.NAME'       (prints the records, one per line)

Environment: MFHOST (default localhost), MFUSER, MFPASS (required).
Needs s3270 on the PATH. Works from the dev container, because it only
uses the network, like a real mainframe user.

It logs on to TSO, sends LIST, pages through the output and always logs
off again. Records are read up to 80 columns wide, including the last one
(see join_wrapped). It never sends the password when the user ID is already in use
(a rejected logon would swallow the password as a command), and it never
types LOGOFF unless the last screen line is READY.
"""
import os
import subprocess
import sys
import time


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

    def lines(self):
        """Non-blank screen lines, without the 'data: ' prefix."""
        rows = [l[6:].rstrip() for l in self.cmd("Ascii") if l.startswith("data: ")]
        return [r for r in rows if r.strip()]

    def key(self, k, wait=1.5):
        self.cmd(k)
        time.sleep(wait)

    def send(self, text):
        self.cmd('String("%s")' % text.replace('"', '\\"'))
        self.key("Enter")

    def last(self):
        L = self.lines()
        return L[-1].strip() if L else ""


SCREEN_WIDTH = 80


def join_wrapped(rows):
    """LIST puts one blank in front of every record, so a record that
    fills all 80 columns needs 81 and its last character wraps to the
    start of the next screen row. Join that character back onto its record.
    A wrapped character is a one-character row that does not start with a
    blank (every LIST row does) and follows a row of the full width."""
    out = []
    for r in rows:
        if out and len(out[-1]) == SCREEN_WIDTH and len(r) == 1 and r != " ":
            out[-1] += r
        else:
            out.append(r)
    return out


def stitch(acc, screen):
    """Append the part of `screen` that is new: the screen scrolls, so it
    starts with the tail of what we already have."""
    for k in range(min(len(acc), len(screen)), 0, -1):
        if acc[-k:] == screen[:k]:
            return acc + screen[k:]
    return acc + screen


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    dsn = sys.argv[1]
    host = os.environ.get("MFHOST", "localhost")
    user = os.environ.get("MFUSER")
    pw = os.environ.get("MFPASS")
    if not user or not pw:
        sys.exit("set MFUSER and MFPASS (or mvs/.secrets/env)")

    s = S3270()
    logged_on = False
    try:
        s.cmd("Connect(%s:3270)" % host)
        time.sleep(3)
        s.key("Enter")
        s.send("L " + user)
        screen = "\n".join(s.lines())
        if "IN USE" in screen:
            sys.exit("%s is already logged on (IN USE); nothing was sent" % user)
        if "PASSWORD" not in screen:
            sys.exit("unexpected logon screen:\n" + screen)
        logged_on = True
        s.send(pw)
        for _ in range(10):  # get past the banner and the applications menu
            if s.last() == "READY":
                break
            s.key("PF(3)" if "TSO Applications" in "\n".join(s.lines()) else "Enter")
        else:
            sys.exit("never reached READY")

        s.send("LIST '%s' NONUM" % dsn)
        acc = []
        for _ in range(60):
            scr = s.lines()
            acc = stitch(acc, scr)
            if scr and scr[-1].strip() == "READY":
                break
            s.key("Enter")
        acc = join_wrapped(acc)
        text = "\n".join(acc)
        if "NOT IN CATALOG" in text or "NOT FOUND" in text or "NOT ALLOCATED" in text:
            sys.exit("data set %s not found" % dsn)
        # keep the records between the LIST echo and the trailer; LIST puts
        # one blank in front of every record, which we remove again
        start = next((i for i, l in enumerate(acc) if l.startswith("LIST '")), -1)
        for l in acc[start + 1:]:
            if l.startswith(" PROCESSING HAS BEEN COMPLETED") or l.strip() == "READY":
                break
            if l.strip() in ("***", "0") or l.startswith(" DSNAME=") or l.startswith(" **** TSO"):
                continue
            print(l[1:] if l.startswith(" ") else l)
    finally:
        try:
            for _ in range(8):
                last = s.last()
                if logged_on and last == "READY":
                    s.send("LOGOFF")
                    break
                if not logged_on:
                    break
                s.key("Enter" if last == "***" else "PF(3)")
            s.cmd("Disconnect")
            s.cmd("Quit")
        except Exception:
            pass


if __name__ == "__main__":
    main()
