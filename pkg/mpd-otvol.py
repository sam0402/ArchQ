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
    # metric=['euclidean', 'cosine']
    client.setvol(62)
    while True:
        try:
            if client.idle() == ['mixer']:
                volume = client.status()['volume']
                subprocess.check_call(['curl', '-X', 'PUT', 'http://localhost:3689/api/player/volume?volume='+volume])
        except KeyboardInterrupt:
            break

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--set",  help="Owntone Volume set.", type=int, default=62, required=False)
    group.add_argument("--listen", help="Listen for MPD IDLE signals to do live scanning.",
            action="store_true", default=False)

    args = parser.parse_args()
    client = init_connection()
    if args.listen:
        listen()
    else:
        sys.exit()
    close_connection(client)
