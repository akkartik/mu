# Import JSON from a Slack admin export.
#
# Images downloaded as follows:
#   grep image_72 foc/ -r |grep -v users.json |column 3 |sort |uniq |sed 's/?.*//' |sed 's,\\,,g' |sed 's/"//' |sed 's/", $//' > images.list
#   wget -i images.list --wait=0.1
#   # fix some lying images
#   for f in $(file *.jpg |grep PNG |sed 's/:.*//'); do mv -i $f $(echo $f |sed 's/\.jpg$/.png/'); done
#   #
#   mkdir ppm
#   for f in *.jpg; do jpegtopnm $f |pnmtopnm -plain > ppm/$(echo $f |sed 's/\.jpg$//').ppm; done
#   for f in *.png; do png2pnm -n $f > ppm/$(echo $f |sed 's/\.png$//').ppm; done
#
# Dependencies: python netpbm and my 'column' perl script
#
# Notes on input format:
#   Redundant 'type' field that's always 'message'. Probably an "enterprise" feature.

from sys import argv, stderr
import json
from os import listdir
from os.path import isfile, join, basename, splitext
from urllib.parse import urlparse

channel_id = {}  # name -> index
channels = []

user_id = {}
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
    for filename in listdir(dir):
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
                print(f"(\"@{user['name']}\" {json.dumps(user['real_name'])} [{look_up_ppm_image(user['profile']['image_72']) or ''}])")
#?                 users.append({
#?                     'id': user['id'],
#?                     'username': user['name'],
#?                     'name': user['real_name'],
#?                     'avatar': look_up_ppm_image(user['profile']['image_72']),
#?                 })
                user_id[user['id']] = length
                length += 1

load_users()
for dir in argv[1:]:
    try:
        for filename in filenames(dir):
            for item in contents(filename):
                print(f"({json.dumps(item['name'])} {item['by']} {json.dumps(item['contents'])})")
    except NotADirectoryError:
        pass
