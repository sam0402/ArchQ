#!/usr/bin/env python3
import os
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
                volume = str(round(float(client.status()['volume']) * 0.75, 1)) + '%'
                subprocess.check_call(['amixer', '-M', 'set', 'PCM', volume, '>/dev/null', '2>&1'])
        except KeyboardInterrupt:
            break
    close_connection(client)

listen()
