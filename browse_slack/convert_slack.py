# Import JSON from a Slack admin export into a disk image Qemu can load.
#
# Dependencies: python, netpbm
#
# Step 1: download a Slack archive
#
# Step 2: download user avatars to subdirectory images/ and convert them to PPM in subdirectory images/ppm/
#   mkdir images
#   cd images
#   grep image_72 . -r |grep -v users.json |awk '{print $3}' |sort |uniq |sed 's/?.*//' |sed 's,\\,,g' |sed 's/"//' |sed 's/",$//' > images.list
#   wget -i images.list --wait=0.1
#   # fix some lying images
#   for f in $(file *.jpg |grep PNG |sed 's/:.*//'); do mv -i $f $(echo $f |sed 's/\.jpg$/.png/'); done
#   #
#   mkdir ppm
#   for f in *.jpg; do jpegtopnm $f |pnmtopnm -plain > ppm/$(echo $f |sed 's/\.jpg$//').ppm; done
#   for f in *.png; do png2pnm -n $f > ppm/$(echo $f |sed 's/\.png$//').ppm; done
#
# Step 3: construct a disk image out of the archives and avatars
#   cd ../..  # go back to parent of images/
#   dd if=/dev/zero of=data.img count=201600  # 100MB
#   python path/to/convert_slack.py |dd of=data.img conv=notrunc
# Currently this process yields errors for ~70 items on the Future of Software
# group. We fail to load those.
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

for channel in json.load(open('channels.json')):
    for filename in sorted(listdir(channel['name'])):
        with open(join(channel['name'], filename)) as f:
            for item in json.load(f):
                try:
                    if 'thread_ts' in item:
                        # comment
                        print(f"({json.dumps(item['ts'])} {json.dumps(item['thread_ts'])} {json.dumps(channel['name'])} {by(item)} {json.dumps(item['text'])})")
                    else:
                        # top-level post
                        print(f"({json.dumps(item['ts'])} {json.dumps(               '')} {json.dumps(channel['name'])} {by(item)} {json.dumps(item['text'])})")
                except KeyError:
                    stderr.write(repr(item)+'\n')
