#!/usr/bin/env python3
"""Send a command to the Hercules web console and print what the system log says.

usage: console.py 'COMMAND'     send it (an MVS console command starts with /, for
                                example '/D T' or '/C U=HERC04'; anything else is a
                                Hercules command, for example 'devlist')
       console.py               only print the latest log lines

Environment: MFHOST (default localhost), MFWEBPORT (default 8038),
MFWAIT seconds to wait for the reply (default 3), MFLINES log lines to
read (default 40).

It posts the same form as the browser's command box (command=...&send=Send)
and reads the log page. The log is plain HTML, so nothing needs refreshing:
every request returns the current log. Working from the dev container, use
MFHOST=172.17.0.1. Only the human decides on commands that cancel users or
change the system; this script does not ask.
"""
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HOST = os.environ.get("MFHOST", "localhost")
PORT = os.environ.get("MFWEBPORT", "8038")
URL = "http://%s:%s/cgi-bin/tasks/syslog" % (HOST, PORT)
LINES = os.environ.get("MFLINES", "40")


def log_lines():
    """The log lines (time stamp first) from the syslog page."""
    req = urllib.request.Request(URL, headers={"Cookie": "msgcount=" + LINES})
    with urllib.request.urlopen(req, timeout=10) as r:
        html = r.read().decode("latin-1")
    text = re.sub(r"<[^>]*>", "", html).replace("&nbsp;", " ").replace("\r", "")
    return [l for l in text.split("\n") if re.match(r"\d\d\.\d\d\.\d\d ", l)]


def send(command):
    data = urllib.parse.urlencode({
        "command": command, "send": "Send", "autorefresh": "1",
        "refresh_interval": "5", "msgcount": LINES}).encode()
    with urllib.request.urlopen(urllib.request.Request(URL, data=data), timeout=10) as r:
        r.read()


def main():
    if len(sys.argv) > 2:
        sys.exit(__doc__)
    before = log_lines()
    if len(sys.argv) == 2:
        send(sys.argv[1])
        time.sleep(float(os.environ.get("MFWAIT", "3")))
        after = log_lines()
        seen = set(before)
        new = [l for l in after if l not in seen] or after[-5:]
        print("\n".join(l[:140] for l in new))
    else:
        print("\n".join(l[:140] for l in before[-15:]))


if __name__ == "__main__":
    main()
