#!/usr/bin/python3
import requests
import glob
import re
import argparse
import urllib.parse
from bs4 import BeautifulSoup
from itertools import count

MAXIMAGE = True
MULTI_ARTIST = False

HEADERS = ({'User-Agent':
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36',
        'Accept-Language': 'en-US, en;q=0.5'})

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
    return soup.find('span', attrs={'class':'album-title'}).text

def album_artist(soup):
    return soup.find('span', attrs={'class':'artist-name'}).text

def track_year(soup):
    return soup.find('li', attrs={'class':'album-meta__item'}).text

def album_cover(soup):
    return soup.find('img', attrs={'class':'album-cover__image'})

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
    parser.add_argument("-W", type=int, default='1')
    args = parser.parse_args()

    url = input("Enter an Qobuz album URL or html file: ")
    if url[0:4] == 'http':
        webpage = requests.get(url, headers=HEADERS).content
    else:
        webpage = open(url,'r').read()
    soup = BeautifulSoup(webpage, "lxml")

    album = album_title(soup).strip().split("\n")[0]
    titles = track_titles(soup)
    nums = track_nums(soup)
    t_artists = track_artists(soup)
    infos = track_infos(soup)
    metas = album_metas(soup)
    # durations = track_durations(soup)
    artist = album_artist(soup)
    label = metas.get('Label', '').split(" ")[0]
    year = re.findall("\d+", track_year(soup))[-1]
    # description = album_description(soup)

    # Query Catalog No from Prestomusic
    query = album + ' ' + artist + ' ' + label
    catalogurl = "https://www.prestomusic.com/classical/search?search_query=" + urllib.parse.quote(query)
    catalog = requests.get(catalogurl, headers=HEADERS).content
    catalog_soup = BeautifulSoup(catalog, "lxml")
    catalog_no = album_no(catalog_soup)

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
    file.write(f"DCOMPOSER={metas.get('Composer', '').strip()}\n")
    file.write(f"DYEAR={year}\n")
    file.write(f"DGENRE={metas.get('Genre', '').strip()}\n")
    file.write(f"DCATALOGNO={catalog_no}\n")

    ### Track Name
    discount = 0
    for i, title, num  in zip(count(0), titles, nums):
        if num.strip() == '1':
            discount = discount + 1
        if discount == args.W:
            file.write(f"TTITLE{int(num.strip())-1}={title.strip()}\n")
            ## Multi Artists
            # if MULTI_ARTIST and len(t_artists) != 0:
            #     file.write(f"{t_artists[i].strip()} / ")
            # file.write(f"{title.strip()}\n")
            # print(f"TTITLE{num}={t_artist.strip()}\n")

    ### Composer
    discount = 0
    tcount = 0
    for info_text, num in zip(infos[::2], nums):
        if num.strip() == '1':
            discount += 1

        if discount == args.W:
            for infoitem in info_text.strip().split(' - '):
                parts = [p.strip() for p in infoitem.split(', ', 1)]
                if len(parts) == 2 and parts[1] == 'Composer':
                    composer = parts[0]
                    file.write(f"TCOMPOSER{int(num.strip())-1}={composer}\n")
            tcount += 1

    ### EXTEND
    file.write(f"EXTD=\n")
    for j in range(tcount):
        file.write(f"EXTT{j}=\n")
    file.write(f"PLAYORDER=\n")
    # file.write(f"COMMENT={metas[len(metas)-2].strip()}\n")

file.close()

## Cover image
image_url = album_cover(soup)['src']
maximg_url = image_url.split('_600.jpg')[0] + '_max.jpg'
coverfile = dbfile.split('/cddbread.0')[0] + '/cover.jpg'
cover = requests.get(maximg_url)

fp = open(coverfile, 'wb')
if MAXIMAGE and cover.status_code:
    fp.write(cover.content)
else:
    cover = requests.get(image_url)
    if cover.status_code:
        fp.write(cover.content)
fp.close()
