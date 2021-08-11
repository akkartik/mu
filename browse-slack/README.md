To try it out (on Linux; it's unusably slow on other platforms):

1. Import a Slack archive into the data disk by following the instructions at
   the top of `browse-slack/convert_slack.py`.

2. Build the code disk.

```
./translate browse-slack/*.mu
```

3. Run the code and data disks:

```
qemu-system-i386 -accel kvm -m 2G -hda code.img -hdb path/to/data.img
```
