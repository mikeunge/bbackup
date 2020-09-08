# 💾 bbackup.sh

### About

bbackup.sh is a small but powerfull tool for creating backups.
It's highly configurable (bbackup.default.conf) and comes in very handy for servers or machines that just run.

The script logs *everything* it does on different levels and it sends you a status *e-mail* when it has finished.

You can define up to two (2) different mounting points with associated path.


### Requirements

To function properly it depends on others work such as:
    - **smb/cifs** for mounting network drives, 
    - **rsnapshot** to make the backup happening,
    - **mail/sendmail/mutt** as a e-mail gateway,
    - **tar** for compressing the files/folders


### Usage

I think this script will most likely be run by a *cron daemon*, so here is a blueprint of one of my production machines:

`# Runs bbackup.sh with command daily (executes: rsnapshot daily)`
`00 19 * * 1-5 bash /root/maint/bbackup/bbackup.sh daily`
`# Execute bbackup.sh on sundays only.`
`00 19 * * 0 bash /root/maint/bbackup/bbackup.sh weekly`
`# Create a monthly backup on every first (1.) of a month.`
`00 19 1 * * bash /root/maint/bbackup/bbackup.sh monthly`


### Todo

- [x] Better documentation
- [x] Add ***CHANGELOG.md***
- [x] More configuration possibilities
- [ ] Re-Do the ***README.md*** file
- [x] Add skip option for network mount
- [x] Add routine for delting /tmp files
- [x] Use local variables instead of global once
- [x] Add a test functionallity
- [ ] Bug fixes and tests...
- [ ] ~Use rsync instead of rsnapshot when compression is turned on~


