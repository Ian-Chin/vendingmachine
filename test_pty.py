#!/usr/bin/env python3
"""Drive ./vending through a real pty so the termios password-masking path runs.

Checks that the password is NOT echoed back, that login succeeds, and that the
terminal's ECHO flag is restored afterwards.
"""
import os, pty, re, select, termios, time

MASTER, SLAVE = pty.openpty()
before = termios.tcgetattr(SLAVE)

pid = os.fork()
if pid == 0:
    os.setsid()
    os.dup2(SLAVE, 0)
    os.dup2(SLAVE, 1)
    os.dup2(SLAVE, 2)
    os.close(MASTER)
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    os.execv("./vending", ["./vending"])

os.close(SLAVE)
out = b""


def pump(seconds=0.4):
    global out
    end = time.time() + seconds
    while time.time() < end:
        r, _, _ = select.select([MASTER], [], [], 0.05)
        if r:
            try:
                out += os.read(MASTER, 4096)
            except OSError:
                return


for keys in (b"2\n", b"admin\n", b"admin123\n", b"\n", b"X\n"):
    pump(0.3)
    os.write(MASTER, keys)
pump(0.5)

try:
    os.waitpid(pid, 0)
except ChildProcessError:
    pass

after = termios.tcgetattr(MASTER)
text = re.sub(rb"\x1b\[[0-9;]*[A-Za-z]", b"", out).decode(errors="replace")

print("password echoed back :", "admin123" in text)
print("login granted        :", "Access granted" in text)
print("ECHO restored        :", bool(after[3] & termios.ECHO))
