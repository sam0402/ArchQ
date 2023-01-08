#!/usr/bin/env python3
import os
import argparse
import subprocess
from mpd import MPDClient

def init_connection():
    """
    Returns an MPDClient connection.
    """
    # Get MPD connection settings
    try:
        mpd_host = os.environ["MPD_HOST"]
        if "@" in mpd_host:
            mpd_password, mpd_host = mpd_host.split("@")
    except KeyError:
        mpd_host = "localhost"
        mpd_password = None
    try:
        mpd_port = os.environ["MPD_PORT"]
    except KeyError:
        mpd_port = 6600

    # Connect to MPD
    client = MPDClient()
    client.connect(mpd_host, mpd_port)
    if mpd_password is not None:
        client.password(mpd_password)
    return client

def close_connection(client):
    """
    Closes an MPDClient connection.
    """
    client.close()
    client.disconnect()

def listen():
    """
    Listen for additions in MPD library using MPD IDLE and handle them
    immediately.
    """
    conf_path = os.path.join("/etc/blissify.conf")
    metric=['euclidean', 'cosine']
    client = init_connection()
    while True:
        try:
            if client.idle() == ['mixer']:
                volume = str(round(float(client.status()['volume']) * 0.9, 1)) + '%'
                subprocess.check_call(['amixer', '-M', 'set', 'MPD', volume, 'unmute', '>/dev/null', '2>&1'])
        except KeyboardInterrupt:
            break
    close_connection(client)

def vol_up():
    """
    Set Volume of ALSA
    """
    client = init_connection()
    client.volume(3)
    subprocess.check_call(['amixer', 'set', 'MPD', 'unmute', '>/dev/null', '2>&1'])
    close_connection(client)

def vol_down():
    client = init_connection()
    client.volume(-3)
    subprocess.check_call(['amixer', 'set', 'MPD', 'unmute', '>/dev/null', '2>&1'])
    close_connection(client)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--up", help="ALSA Volume up.",
                       action="store_true", default=False)
    group.add_argument("--down", help="ALSA Volume down.",
                       action="store_true", default=False)
    group.add_argument("--listen",
                       help="Listen for MPD IDLE signals to do live scanning.",
                       action="store_true", default=False)

    args = parser.parse_args()

    if args.listen:
        listen()
    elif args.up:
        vol_up()
    elif args.down:
        vol_down()
    else:
        sys.exit()
