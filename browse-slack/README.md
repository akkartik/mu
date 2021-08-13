To try it out:

1. Import a tiny test Slack archive into the data disk by running:
   ```
   tools/image-data 10 < browse-slack/test_data
   ```

2. Build the code disk (on Linux; see the top-level Readme for other platforms)
   ```
   ./translate browse-slack/*.mu
   ```

3. Run the code and data disks:
   ```
   qemu-system-i386 -m 2G -hda code.img -hdb path/to/data.img
   ```

You should now see some text and images in Qemu. For a real Slack archive,
follow the instructions at the top of `browse-slack/convert_slack.py`. You'll
also want to tweak the `sector-count` in browse-slack/main.mu which affects
the number of sectors read from the data disk.
