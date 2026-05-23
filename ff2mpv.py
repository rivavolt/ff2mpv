#!/usr/bin/env python3

import json
import os
import platform
import struct
import sys
import subprocess


def main():
    message = get_message()
    url = message.get("url")
    options = message.get("options") or []
    title = message.get("title")

    # Respond immediately so Chromium doesn't kill the native messaging host
    send_message("ok")

    kwargs = {}
    # https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging#Closing_the_native_app
    if platform.system() == "Windows":
        kwargs["creationflags"] = subprocess.CREATE_BREAKAWAY_FROM_JOB

    if platform.system() == "Darwin":
        path = os.environ.get("PATH")
        os.environ["PATH"] = f"/opt/homebrew/bin:/usr/local/bin:{path}"

    title_args = [f"--title={title}"] if title else []
    args = ["mpv", "--no-terminal", *title_args, *options, "--", url]
    subprocess.Popen(args, **kwargs)


# https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Native_messaging#App_side
def get_message():
    raw_length = sys.stdin.buffer.read(4)
    if not raw_length:
        return {}
    length = struct.unpack("@I", raw_length)[0]
    message = sys.stdin.buffer.read(length).decode("utf-8")
    return json.loads(message)


def send_message(message):
    # https://stackoverflow.com/a/56563264
    # https://docs.python.org/3/library/json.html#basic-usage
    # To get the most compact JSON representation, you should specify
    # (',', ':') to eliminate whitespace.
    content = json.dumps(message, separators=(",", ":")).encode("utf-8")
    length = struct.pack("@I", len(content))
    sys.stdout.buffer.write(length)
    sys.stdout.buffer.write(content)
    sys.stdout.buffer.flush()


if __name__ == "__main__":
    main()
