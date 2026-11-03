# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-03

### Added

- A menu bar app for scheduling centralOS agent tasks that run through Claude Code on this Mac.
- Tasks with a name, instructions, a working folder and a schedule: Off, Daily, Weekly on chosen days, or Monthly on the 1st to 28th, with a 24-hour time picker.
- Tasks run under launchd, so they keep running when the app is closed and catch up after sleep.
- A launch page for connecting centralOS and Claude, with optional notifications and open at login.
- The centralOS MCP status in the menu, with Connect, Sign in and Re-add.
- Run now, Last run (resumes the session in Terminal) and Check tools on each task.
- Pause and Resume for all schedules.
- Silent notifications with each task's result.
- A saved change to a running task waits until that run finishes.
