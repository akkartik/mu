# Import JSON from a Slack admin export into a disk image Qemu can load.
#
# Dependencies: python, netpbm
#
# Images downloaded as follows:
#   grep image_72 . -r |grep -v users.json |awk '{print $3}' |sort |uniq |sed 's/?.*//' |sed 's,\\,,g' |sed 's/"//' |sed 's/",$//' > images.list
#   wget -i images.list --wait=0.1
#   # fix some lying images
#   for f in $(file *.jpg |grep PNG |sed 's/:.*//'); do mv -i $f $(echo $f |sed 's/\.jpg$/.png/'); done
#   #
#   mkdir ppm
#   for f in *.jpg; do jpegtopnm $f |pnmtopnm -plain > ppm/$(echo $f |sed 's/\.jpg$//').ppm; done
#   for f in *.png; do png2pnm -n $f > ppm/$(echo $f |sed 's/\.png$//').ppm; done
#
# To construct the disk image:
#   dd if=/dev/zero of=data.img count=201600  # 100MB
#   python convert_slack.py |dd of=data.img conv=notrunc
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

channels = {}

user_id = {}  # name -> index
users = []

items = []

def contents(filename):
    with open(filename) as f:
        for item in json.load(f):
            try:
                if 'thread_ts' in item:
                    # comment
                    yield {
                      'name': f"/{item['thread_ts']}/{item['ts']}",
                      'contents': item['text'],
                      'by': user_id[item['user']],
#?                       'by': users[user_id[item['user']]]['avatar'][0:100],
                    }
                else:
                    # top-level post
                    yield {
                      'name': f"/{item['ts']}",
                      'contents': item['text'],
                      'by': user_id[item['user']],
#?                       'by': users[user_id[item['user']]]['avatar'][0:100],
                    }
            except KeyError:
                stderr.write(repr(item)+'\n')

def filenames(dir):
    for filename in sorted(listdir(dir)):
        result = join(dir, filename)
        if isfile(result):
            yield result

def look_up_ppm_image(url):
    file_root = splitext(basename(urlparse(url).path))[0]
    filename = f"images2/ppm/{file_root}.ppm"
    if isfile(filename):
        with open(filename) as f:
            return f.read()

def load_users():
    stderr.write('loading users..\n')
    length = 0
    with open('users.json') as f:
        for user in json.load(f):
#?             if user['deleted']:
#?                 continue
            if user['id'] not in user_id:
                if 'real_name' not in user:
                    user['real_name'] = ''
                print(f"({json.dumps(user['id'])} \"@{user['name']}\" {json.dumps(user['real_name'])} [{look_up_ppm_image(user['profile']['image_72']) or ''}])")
#?                 users.append({
#?                     'id': user['id'],
#?                     'username': user['name'],
#?                     'name': user['real_name'],
#?                     'avatar': look_up_ppm_image(user['profile']['image_72']),
#?                 })
                user_id[user['id']] = length
                length += 1

def load_channels():
    stderr.write('loading channels..\n')
    with open('channels.json') as f:
        for channel in json.load(f):
            channels[channel['id']] = channel['name']

load_channels()
load_users()
for dir in channels.values():
    try:
        for filename in filenames(dir):
            print(filename)
            for item in contents(filename):
                print(f"({json.dumps(item['name'])} {json.dumps(dir)} {item['by']} {json.dumps(item['contents'])})")
    except NotADirectoryError:
        pass