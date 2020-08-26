# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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


## [1.0.3] - 24.08.2020
### Added ✨
- CHANGELOG.md file 🥳
- Compression functionallity in the bbackup script.
- Compression trigger and configuration in the bbackup configuration file.
- /tests/* to the project. New implementations are stored and tested in there.

### Changed ⚠️
- Workflow for panic() function.
- send_email() case and execution.
