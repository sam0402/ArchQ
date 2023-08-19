#!/usr/bin/python
import requests
import glob
import re
import argparse
from bs4 import BeautifulSoup
from itertools import count

HEADERS = ({'User-Agent':
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36',
        'Accept-Language': 'en-US, en;q=0.5'})

def get_soup(url):
    r = requests.get(url)
    r.raise_for_status()
    return BeautifulSoup(r.text, 'lxml')

def track_titles(soup):
    attrs = {'itemprop': 'name'}
    return [div.text.strip() for div in soup.find_all('div', attrs=attrs)]

def track_artists(soup):
    attrs = {'class': 'track__item track__item--artist track__item--performer'}
    return [div.text.strip() for div in soup.find_all('div', attrs=attrs)]

def track_infos(soup):
    attrs = {'class': 'track__info'}
    return [p.text.strip() for p in soup.find_all('p', attrs=attrs)]

def album_metas(soup):
    attrs = {'class': 'album-about__item album-about__item--link'}
    return [a.text.strip() for a in soup.find_all('a', attrs=attrs)]

# def track_durations(soup):
#     attrs = {'class': 'track__item track__item--duration'}
#     return [span.text.strip() for span in soup.find_all('td', attrs=attrs)]

def album_title(soup):
    return soup.find('h1', attrs={'class':'album-meta__title'}).text

def album_artist(soup):
    return soup.find('h2', attrs={'class':'album-meta__artist'}).text

def track_year(soup):
    return soup.find('li', attrs={'class':'album-meta__item'}).text

def album_cover(soup):
    return soup.find('img', attrs={'class':'album-cover__image'})

# def album_description(soup):
#     return soup.find('p', attrs={'class':'album-info__text'}).text

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--workpath", default='./abcde.*')
    args = parser.parse_args()
    url = input("Enter an Qobuz album url: ")
    webpage = requests.get(url, headers=HEADERS)
    soup = BeautifulSoup(webpage.content, "lxml")

    album = album_title(soup)
    titles = track_titles(soup)
    t_artists = track_artists(soup)
    infos = track_infos(soup)
    metas = album_metas(soup)
    # durations = track_durations(soup)
    artist = album_artist(soup)
    composer = metas[len(metas)-3].strip()
    year = re.findall("\d+", track_year(soup))[-1]
    cover_url = album_cover(soup)['src']

    # description = album_description(soup)

dbfile=glob.glob(rf"{args.workpath}/cddbread.0")[0]

with open(dbfile, "r+") as file:
    cddb = file.readline()
    while cddb :
        cddb = file.readline()
        if cddb.find('DISCID=') == 0 :
            break
    file.seek(file.tell())
    file.truncate()

    file.write(f"DTITLE={artist.strip()} / {album.strip()}\n")
    # file.write(f"COMPOSER={album.strip().split(':')[0]}\n")
    file.write(f"COMPOSER={composer}\n")
    file.write(f"DYEAR={year}\n")
    file.write(f"DGENRE={metas[-1].strip()}\n")
    # print(f"DGENRE={metas[4].strip()}\n")

    for i, title in zip(count(0), titles):
        file.write(f"TTITLE{i}=")
        ## Multi Artists
        # if len(t_artists) != 0:
        #     file.write(f"{t_artists[i].strip()} / ")
        file.write(f"{title.strip()}\n")
        # print(f"TTITLE{i}={t_artist.strip()}\n")

    for i, info in zip(count(0), infos[::2]):
        for infoitem in info.strip().split(' - '):
            if len(infoitem.strip().split(', ')) == 2 and infoitem.strip().split(', ')[1] == 'Composer':
                file.write(f"TCOMPOSER{i}={infoitem.strip().split(', ')[0].title()}\n")

    file.write(f"EXTD=\n")
    for i, title in zip(count(0), titles):
        file.write(f"EXTT{i}=\n")
    file.write(f"PLAYORDER=\n")
    # file.write(f"COMMENT={metas[len(metas)-2].strip()}\n")

file.close()

## Cover image
coverfile = dbfile.split('/cddbread.0')[0] + '/cover.jpg'
image = requests.get(cover_url)

if image.status_code:
    fp = open(coverfile, 'wb')
    fp.write(image.content)
    fp.close()