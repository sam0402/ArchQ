#!/usr/bin/python3
import requests
import glob
import re
import argparse
import urllib.parse
import subprocess
import sys
import os
from bs4 import BeautifulSoup
from itertools import count

MAXIMAGE = True

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US, en;q=0.5'
}

def fetch_url(url, is_ajax=False):
    curl_cmd = [
        'curl', '-s', '-L',
        '-H', f'User-Agent: {HEADERS["User-Agent"]}',
        '-H', 'Accept-Language: en-US,en;q=0.5',
    ]
    if is_ajax:
        curl_cmd += [
            '-H', 'Accept: text/html, */*; q=0.01',
            '-H', 'X-Requested-With: XMLHttpRequest',
            '-H', 'Sec-Fetch-Dest: empty',
            '-H', 'Sec-Fetch-Mode: cors',
            '-H', 'Sec-Fetch-Site: same-origin',
        ]
    else:
        curl_cmd += [
            '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            '-H', 'Sec-Fetch-Dest: document',
            '-H', 'Sec-Fetch-Mode: navigate',
            '-H', 'Sec-Fetch-Site: none',
            '-H', 'Sec-Fetch-User: ?1',
        ]
    curl_cmd.append(url)
    res = subprocess.run(curl_cmd, capture_output=True)
    if res.returncode == 0 and res.stdout:
        return res.stdout
    # Fallback to requests if curl fails
    headers = dict(HEADERS)
    if is_ajax:
        headers['X-Requested-With'] = 'XMLHttpRequest'
    resp = requests.get(url, headers=headers, timeout=15)
    return resp.content

def load_all_tracks(soup, url=""):
    player_tracks = soup.find(id='playerTracks')
    if not player_tracks:
        return

    album_id = player_tracks.get('data-itemid')
    if not album_id:
        more_btn = soup.find('button', class_='player-more__button')
        if more_btn:
            album_id = more_btn.get('data-itemid')

    try:
        nb_tracks = int(player_tracks.get('data-nbtracks', 0))
    except (ValueError, TypeError):
        nb_tracks = 0

    try:
        limit = int(player_tracks.get('data-limit', 50))
    except (ValueError, TypeError):
        limit = 50

    store = player_tracks.get('data-store')
    if not store and url:
        match = re.search(r"qobuz\.com/([a-z]{2}-[a-z]{2})/", url)
        if match:
            store = match.group(1)
    if not store:
        store = 'gb-en'

    current_tracks = len(player_tracks.find_all('div', class_='track'))
    offset = current_tracks

    while album_id and (offset < nb_tracks or soup.find('button', class_='player-more__button')):
        ajax_url = f"https://www.qobuz.com/v4/ajax/album/load-tracks?albumId={album_id}&offset={offset}&limit={limit}&store={store}"
        ajax_content = fetch_url(ajax_url, is_ajax=True)
        if not ajax_content:
            break
        ajax_soup = BeautifulSoup(ajax_content, "lxml")
        new_tracks = ajax_soup.find_all('div', class_='track')
        if not new_tracks:
            break
        for tr in new_tracks:
            player_tracks.append(tr)
        offset += len(new_tracks)
        if len(new_tracks) < limit:
            break

def track_titles(soup):
    return [
        div.get('title')
        for div in soup.find_all('div', class_='track__items')
        if div.get('title')
    ]

def track_artists(soup):
    attrs = {'class': 'track__item track__item--artist track__item--performer'}
    return [div.text.strip() for div in soup.find_all('div', attrs=attrs)]

def track_infos(soup):
    attrs = {'class': 'track__info'}
    return [p.text.strip() for p in soup.find_all('p', attrs=attrs)]

def album_metas(soup):
    metas = {}
    for li in soup.find_all('li', class_='album-about__item'):
        text = li.get_text(separator=' ', strip=True)
        if ':' in text:
            key, value = text.split(':', 1)
            key = key.strip()
            value = ' '.join(a.get_text(strip=True) for a in li.find_all('a'))
            metas[key] = value
    return metas

def track_nums(soup):
    attrs = {'class': 'track__item track__item--number'}
    return [div.text.strip() for div in soup.find_all('div', attrs=attrs)]

# def track_durations(soup):
#     attrs = {'class': 'track__item track__item--duration'}
#     return [span.text.strip() for span in soup.find_all('td', attrs=attrs)]

def album_title(soup):
    elem = soup.find('span', attrs={'class': 'album-title'}) or soup.find('h1', attrs={'class': 'album-meta__title'})
    return elem.text.strip() if elem else ''

def album_artist(soup):
    elem = soup.find('span', attrs={'class': 'artist-name'}) or soup.find('span', attrs={'class': 'album-meta__artist'})
    return elem.text.strip() if elem else ''

def track_year(soup):
    elem = soup.find('li', attrs={'class': 'album-meta__item'})
    return elem.text.strip() if elem else ''

def album_cover(soup):
    return soup.find('img', attrs={'class': 'album-cover__image'})

def album_no(soup):
    for li in soup.find_all('li'):
        strong = li.find('strong')
        if strong and 'Catalogue No' in strong.get_text():
            return li.get_text(strip=True).replace(strong.get_text(), '').strip()
    return None

# def album_description(soup):
#     return soup.find('p', attrs={'class':'album-info__text'}).text

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--workpath", default='./abcde.*')
    parser.add_argument("-W", type=int, default=1)
    args = parser.parse_args()

    url = input("Enter an Qobuz album URL or html file: ").strip()
    if url.startswith('http://') or url.startswith('https://'):
        webpage = fetch_url(url)
    else:
        with open(url, 'r', encoding='utf-8', errors='ignore') as f:
            webpage = f.read()
    soup = BeautifulSoup(webpage, "lxml")
    load_all_tracks(soup, url)

    album = album_title(soup).strip().split("\n")[0]
    titles = track_titles(soup)
    nums = track_nums(soup)
    t_artists = track_artists(soup)
    infos = track_infos(soup)
    metas = album_metas(soup)
    # durations = track_durations(soup)
    artist = album_artist(soup)
    label = metas.get('Label', '').split(" ")[0]
    year_matches = re.findall(r"\d+", track_year(soup))
    year = year_matches[-1] if year_matches else ''
    # description = album_description(soup)

    # Query Catalog No from Prestomusic
    catalog_no = ''
    try:
        query = album + ' ' + artist + ' ' + label
        catalogurl = "https://www.prestomusic.com/classical/search?search_query=" + urllib.parse.quote(query)
        curl_cat = [
            'curl', '-s', '-L',
            '-H', f'User-Agent: {HEADERS["User-Agent"]}',
            '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            '-H', 'Accept-Language: en-US,en;q=0.5',
            catalogurl
        ]
        res_cat = subprocess.run(curl_cat, capture_output=True, timeout=10)
        if res_cat.returncode == 0 and res_cat.stdout:
            catalog_soup = BeautifulSoup(res_cat.stdout, "lxml")
            c_no = album_no(catalog_soup)
            if c_no:
                catalog_no = c_no
        if not catalog_no:
            catalog = requests.get(catalogurl, headers=HEADERS, timeout=10).content
            catalog_soup = BeautifulSoup(catalog, "lxml")
            c_no = album_no(catalog_soup)
            if c_no:
                catalog_no = c_no
    except Exception:
        catalog_no = ''

    if catalog_no is None:
        catalog_no = ''

    matches = glob.glob(rf"{args.workpath}/cddbread.0")
    if not matches:
        print(f"Error: {args.workpath}/cddbread.0 not found.")
        sys.exit(1)
    dbfile = matches[0]

    with open(dbfile, "r+") as file:
        cddb = file.readline()
        while cddb:
            cddb = file.readline()
            if cddb.find('DISCID=') == 0:
                break
        file.seek(file.tell())
        file.truncate()

        file.write(f"DTITLE={artist.strip()} / {album.strip()}\n")
        # file.write(f"COMPOSER={album.strip().split(':')[0]}\n")
        file.write(f"DCOMPOSER={metas.get('Composer', '').strip()}\n")
        file.write(f"DYEAR={year}\n")
        file.write(f"DGENRE={metas.get('Genre', '').strip()}\n")
        file.write(f"DCATALOGNO={catalog_no}\n")

        ### Track Name
        discount = 0
        for i, title, num, info_text in zip(count(0), titles, nums, infos[::2]):
            if num.strip() == '1':
                discount = discount + 1
            if discount == args.W:
                performers = []
                for item in info_text.strip().split(' - '):
                    parts = [p.strip() for p in item.split(', ')]
                    if len(parts) >= 2 and ('Performer' in parts[1:] or 'MainArtist' in parts[1:]):
                        performers.append(parts[0])

                performers = list(dict.fromkeys(performers))

                file.write(f"TTITLE{int(num.strip())-1}={title.strip()}")
                # Multi Artists (only append if performers differ from album artist)
                if performers and ', '.join(performers) != artist:
                    file.write(f" / {', '.join(performers)}")
                file.write("\n")

        ### Composer
        discount = 0
        tcount = 0
        for info_text, num in zip(infos[::2], nums):
            if num.strip() == '1':
                discount += 1

            if discount == args.W:
                track_composer = ""
                for infoitem in info_text.strip().split(' - '):
                    parts = [p.strip() for p in infoitem.split(', ')]
                    if len(parts) >= 2 and 'Composer' in parts[1:]:
                        track_composer = parts[0]
                        break
                if not track_composer:
                    track_composer = metas.get('Composer', '').strip()
                if track_composer.strip().lower() == 'various composers':
                    track_composer = ""
                file.write(f"TCOMPOSER{int(num.strip())-1}={track_composer}\n")
                tcount += 1

        ### EXTEND
        file.write("EXTD=\n")
        for j in range(tcount):
            file.write(f"EXTT{j}=\n")
        file.write("PLAYORDER=\n")
        # file.write(f"COMMENT={metas[len(metas)-2].strip()}\n")

    ## Cover image
    try:
        cover_elem = album_cover(soup)
        if cover_elem and cover_elem.get('src'):
            image_url = cover_elem['src']
            maximg_url = image_url.split('_600.jpg')[0] + '_max.jpg'
            coverfile = dbfile.split('/cddbread.0')[0] + '/cover.jpg'
            saved = False
            if MAXIMAGE:
                try:
                    cover = requests.get(maximg_url, headers=HEADERS, timeout=10)
                    if cover.status_code == 200 and len(cover.content) > 1000:
                        with open(coverfile, 'wb') as fp:
                            fp.write(cover.content)
                        saved = True
                except Exception:
                    pass
            if not saved:
                try:
                    cover = requests.get(image_url, headers=HEADERS, timeout=10)
                    if cover.status_code == 200 and len(cover.content) > 1000:
                        with open(coverfile, 'wb') as fp:
                            fp.write(cover.content)
                except Exception:
                    pass
    except Exception as e:
        print(f"Warning: Failed to download cover: {e}")
