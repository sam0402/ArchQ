#!/usr/bin/python
import requests
import glob
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
    attrs = {'class': 'a-size-base-plus a-link-normal a-color-base TitleLink a-text-bold'}
    return [a.text for a in soup.find_all('a', attrs=attrs)]

def track_durations(soup):
    attrs = {'class': 'a-text-right a-align-center'}
    return [td.text.strip() for td in soup.find_all('td', attrs=attrs)]

def track_artist(soup):
    return soup.find('a', attrs={'id':'ProductInfoArtistLink'}).text

def track_album(soup):
    return soup.find('h1', attrs={'class':'a-size-large a-spacing-micro'}).text

def track_year(soup):
    return soup.find('span', attrs={'id':'ProductInfoReleaseDate'}).text

if __name__ == "__main__":
    url = input("Please enter an Amazon music url:")
    webpage = requests.get(url, headers=HEADERS)
    soup = BeautifulSoup(webpage.content, "lxml")

    album = track_album(soup)
    titles = track_titles(soup)
    # durations = track_durations(soup)
    artist = track_artist(soup)
    year = track_year(soup)

dbfile=glob.glob(r"./abcde.*/cddbread.0")[0]

with open(dbfile, "r+") as file:
    cddb = file.readline()
    while cddb :
        cddb = file.readline()
        if cddb.find('DISCID=') == 0 :
            break
    file.seek(file.tell())
    file.truncate()

    file.write(f"DTITLE={artist.strip()} / {album.strip()}\n")
    file.write(f"COMPOSER={album.strip().split(':')[0]}\n")
    file.write(f"DYEAR={year.split()[2]}\n")
    file.write(f"DGENRE=\n")

    for i, title in zip(count(0), titles):
        file.write(f"TTITLE{i}={title.strip()}\n")
    file.write(f"EXTD=\n")

    for i, title in zip(count(0), titles):
        file.write(f"EXTT{i}=\n")
    file.write(f"PLAYORDER=\n")

file.close()