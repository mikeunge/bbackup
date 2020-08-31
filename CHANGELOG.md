# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3.3] - 31.08.2020
### Added ✨
- Cleanup routine at the **end** of the script
- More wait statements for the `send_email` function

### Changed ⚠️
- Outsourced `log_rotate` as well as the `cleanup`


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
