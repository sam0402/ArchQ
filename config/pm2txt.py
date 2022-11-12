#!/usr/bin/python
import requests
import glob
from bs4 import BeautifulSoup
from itertools import count

HEADERS = ({'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36',
        'Accept-Language': 'en-US, en;q=0.5'})

def get_soup(url):
    r = requests.get(url)
    r.raise_for_status()
    return BeautifulSoup(r.text, 'lxml')

def track_titles(soup):
    attrs = {'class': 'c-track__title'}
    return [p.text for p in soup.find_all('p', attrs=attrs)]

def track_durations(soup):
    attrs = {'button': 'data-ora-prim'}
    return [td.text.strip() for td in soup.find_all('td', attrs=attrs)]

def track_primes(soup):
    attrs = {'button': 'data-ora-prim'}
    return [td.text.strip() for td in soup.find_all('td', attrs=attrs)]

def track_artist(soup):
    return soup.find('div', attrs={'class':'c-product-block__contributors'}).text

def track_album(soup):
    return soup.find('h1', attrs={'class':'c-h1 c-product-block__title'}).text

def track_year(soup):
    return soup.find('ul', attrs={'class':'o-list o-columns--1-2-md'}).text

if __name__ == "__main__":
    url = input("Please enter an prestomusic url:")
    webpage = requests.get(url, headers=HEADERS)
    soup = BeautifulSoup(webpage.content, "lxml")

    album = track_album(soup)
    titles = track_titles(soup)
    primes = track_primes(soup)
    # durations = track_durations(soup)
    artist = track_artist(soup)
    year = track_year(soup)

dbfile="./cddata.txt"

with open(dbfile, "w") as file:
    # cddb = file.readline()
    # while cddb :
    #     cddb = file.readline()
    #     if cddb.find('DISCID=') == 0 :
    #         break
    # file.seek(file.tell())
    # file.truncate()

    file.write(f"DTITLE={artist.strip()} / {album.strip()}\n")
    file.write(f"COMPOSER={album.strip().split(':')[0]}\n")
    file.write(f"DYEAR={year.split()[4]}\n")
    file.write(f"DGENRE=\n")

    for i, title in zip(count(0), titles):
        file.write(f"TTITLE{i}={title.strip().split('Track')[0]}\n")
    file.write(f"EXTD=\n")

    # for i, title in zip(count(0), titles):
    #     file.write(f"EXTT{i}=")
    # file.write(f"PLAYORDER=")
file.close()