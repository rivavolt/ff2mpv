#!/usr/bin/env python3

import json
import os
import platform
import struct
import sys
import subprocess
import shutil
import urllib.request


def is_youtube_live(url):
    """Quick check if a YouTube URL is a live stream by fetching page HTML (~0.2s)."""
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0",
            "Cookie": "CONSENT=YES+1",
        })
        with urllib.request.urlopen(req, timeout=5) as resp:
            html = resp.read(500_000).decode("utf-8", errors="ignore")
            return '"isLive":true' in html
    except Exception:
        return False


def main():
    message = get_message()
    url = message.get("url")
    options = message.get("options") or []

    # Respond immediately so Chromium doesn't kill the native messaging host
    send_message("ok")

    kwargs = {}
    # https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging#Closing_the_native_app
    if platform.system() == "Windows":
        kwargs["creationflags"] = subprocess.CREATE_BREAKAWAY_FROM_JOB

    if platform.system() == "Darwin":
        path = os.environ.get("PATH")
        os.environ["PATH"] = f"/opt/homebrew/bin:/usr/local/bin:{path}"

    # Use streamlink for YouTube live streams (ffmpeg can't auth HLS segments)
    if (
        url
        and "youtube.com" in url
        and shutil.which("streamlink")
        and is_youtube_live(url)
    ):
        mpv = shutil.which("mpv")
        args = ["streamlink", "--player", mpv, "--player-args", "--no-terminal {playerinput}", url, "best"]
    else:
        args = ["mpv", "--no-terminal", *options, "--", url]

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
