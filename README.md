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


### Thanks

I really want to thank [Zordrak](https://github.com/Zordrak/bashlog) for his awesome 'bash logger'.
It really helped me develop the new features and extend it's possibilitys.


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


