# 💾 bbackup.sh

### About

***bbackup.sh*** is a backup script designed to make sure everything is in place and executed in the correct order. It uses *'**rsnapshot**'* for the backups and *'**mutt**'* or *'**sendmail**'* to send status e-mails. 

The script is highly configurarable to suit most needs.



### Requirements

The script needs **bash**, **smb/cifs**, **rsnapshot** and an *e-mail* client like **mutt**.



### Todo

- [x] Better documentation
- [x] Add ***CHANGELOG.md***
- [x] More configuration possibilities
- [ ] Re-Do the ***README.md*** file
- [ ] Add skip option for network mount
- [x] Add routine for delting /tmp files
- [x] Use local variables instead of global once
- [x] Add a test functionallity
- [ ] Bug fixes and tests...
- [ ] Use rsync instead of rsnapshot when compression is turned on

