# Import JSON from a Slack admin export into a disk image Mu can load.
#
# Dependencies: python, wget, awk, sed, netpbm
#
# Step 1: download a Slack archive and unpack it to some directory
#
# Step 2: download user avatars to subdirectory images/ and convert them to PPM in subdirectory images/ppm/
#   grep image_72 . -r |grep -v users.json |awk '{print $3}' |sort |uniq |sed 's/?.*//' |sed 's,\\,,g' |sed 's/"//' |sed 's/",$//' > images.list
#   mkdir images
#   cd images
#   wget -i ../images.list --wait=0.1
#   # fix some lying images
#   for f in $(file *.jpg |grep PNG |sed 's/:.*//'); do mv -i $f $(echo $f |sed 's/\.jpg$/.png/'); done
#   #
#   mkdir ppm
#   for f in *.jpg; do jpegtopnm $f |pnmtopnm -plain > ppm/$(echo $f |sed 's/\.jpg$//').ppm; done
#   for f in *.png; do png2pnm -n $f > ppm/$(echo $f |sed 's/\.png$//').ppm; done
#
# Step 3: construct a disk image out of the archives and avatars
#   cd ..  # go back to the top-level archive directory
#   dd if=/dev/zero of=data.img count=201600  # 100MB
#   python path/to/convert_slack.py > data.out 2> data.err
#   dd if=data.out of=data.img conv=notrunc
# Currently this process yields errors for ~300 items (~70 posts and their comments)
# on the Future of Software group (https://futureofcoding.org/community). We fail to load those.
#
# Notes on input format:
#   Redundant 'type' field that's always 'message'. Probably an "enterprise" feature.

from sys import argv, stderr
import json
from os import listdir
from os.path import isfile, join, basename, splitext
from urllib.parse import urlparse

def look_up_ppm_image(url):
    file_root = splitext(basename(urlparse(url).path))[0]
    filename = f"images/ppm/{file_root}.ppm"
    if isfile(filename):
        with open(filename) as f:
            return f.read()

user_idx = {}
with open('users.json') as f:
    for idx, user in enumerate(json.load(f)):
        if 'real_name' not in user:
            user['real_name'] = ''
        print(f"({json.dumps(user['id'])} \"@{user['name']}\" {json.dumps(user['real_name'])} [{look_up_ppm_image(user['profile']['image_72']) or ''}])")
        user_idx[user['id']] = idx

def by(item):
    return user_idx[item['user']]

item_idx = {}
def parent(item):
    if 'thread_ts' in item and item['thread_ts'] != item['ts']:
        # comment
        return item_idx[item['thread_ts']]
    else:
        return -1

items = []
for channel in json.load(open('channels.json')):
    for filename in sorted(listdir(channel['name'])):
        with open(join(channel['name'], filename)) as f:
            for item in json.load(f):
                item['channel_name'] = channel['name']
                items.append(item)

idx = 0
for item in sorted(items, key=lambda item: item['ts']):
    try:
        print(f"({json.dumps(item['ts'])} {parent(item)} {json.dumps(item['channel_name'])} {by(item)} {json.dumps(item['text'])})")
        item_idx[item['ts']] = idx
        idx += 1  # only increment when actually used and no exception raised
    except KeyError:
        stderr.write(repr(item)+'\n')
