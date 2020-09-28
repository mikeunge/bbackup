# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.6.1] - 28.09.2020
### Fixed 🐞
- The 'printf' output was bricked, all it took to fix are quatation marks for the $variables


## [1.0.6] - 24.09.2020
### Added ✨
- Added compression level (COMP_LVL)


## [1.0.5] - 18.09.2020
### Changed ⚠️
- Echo is now printf
- /dev/null pointers are now better formatted


## [1.0.4] - 08.09.2020
### Added ✨ 
- Skipping the mounting process is now possible
- Compression function can compress and/or archive files and folders
- Createing a .pid file so no more than 1 instance can possibly run
- Statistics and Analytics 

### Changed ⚠️
- Updated README.md
- Cleaned some parts of the code
- Better error handling and error texts
- Logging is more beautiful

### Fixed 🐞
- Sending e-mails
- Rsnapshot error codes


## [1.0.3.4] - 02.09.2020
### Added ✨
- `bbackup` now locks itself (*/var/run/bbackup.pid*)


## [1.0.3.3] - 01.09.2020
### Added ✨
- Cleanup routine at the **end** of the script
- More wait statements for the `send_email` function
- Choose between compression/tar modes (tar, bz2, gz, lmza)

### Changed ⚠️
- Outsourced `log_rotate` as well as the *tmp* `cleanup`
- Toggle *mail* and *sendmail* different

### Fixed 🐞
- `if ! [ -f $RSNAPSHOT_LOG_FILE ]; then` didn't find the file because it looked for a directory: `[ -d $RSNAPSHOT_LOG_FILE ]`
- `date +'%Y-%m-%d %T'` returned an error because of whitespace
- `send_email()` with case `mail|sendmail` couldn't attach `$RSNAPSHOT_LOG_FILE`


## [1.0.3.2] - 31.08.2020
### Added ✨
- Local variables where they should be
- New test fucntion, give the parameter TEST_C and the script will execute in a test envirement
- Analytics - calculate the elapsed time (script start - script end)
- tests/ driectory to the .gitignore

### Changed ⚠️
- Error texts and workflow
- tests/ directory was removed

### Fixed 🐞
- Issue #5 Script crashes when one $COMP_SRC is defined


## [1.0.3.1] - 26.08.2020
### Added ✨
- Multi-Threaded compression
- Logging to file or stdio switch
- Temp file remover routine
- Return codes with specific error messages

### Changed ⚠️
- Swaped time with priority in the log() function
- Error/Logging messages
- Config description
- The project was moved out from Scripts/backupper and is now it's own repo with a new name (bbackup)

### Fixed 🐞
- Issue #1 error with compression algo


## [1.0.3] - 24.08.2020
### Added ✨
- CHANGELOG.md file 🥳
- Compression functionallity in the bbackup script
- Compression trigger and configuration in the bbackup configuration file
- /tests/* to the project. New implementations are stored and tested in there

### Changed ⚠️
- Workflow for panic() function
- send_email() case and execution
