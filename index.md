# Agent Scheduler

Agent Scheduler runs your centralOS agent on your Mac, on a schedule. Connect your centralOS account and say what you want done and when. Each task runs in the background, even when the app is closed.

## Requirements

- macOS 15 or later
- [Claude Code](https://claude.com/claude-code), installed and signed in
- A centralOS account

## Install

1. Download `Agent-Scheduler-<version>.zip` from the latest release.
2. Unzip it and move **Agent Scheduler** to Applications.
3. Open it. The first time, right-click the app and choose **Open**, because builds aren't notarized yet.

The launch page shows what to connect:

- **centralOS** gives your agent your contacts, projects, notes and calendar.
- **Claude account** is the Claude Code sign-in your agent runs on.
- **Notifications** are optional. When a task finishes, you get a silent banner with its result.
- **Open at login** is optional and keeps the menu bar icon after a restart. Tasks run either way.

You can reopen the launch page any time from **Services…** (⌘,) in the menu.

## Using it

Click the menu bar icon to see your tasks. Choose **New task** (⌘N), then set:

- **Schedule**: Off, Daily, Weekly (pick the days) or Monthly (pick a date from the 1st to the 28th), plus a time in 15-minute steps.
- **Instructions**: what the agent should do, in plain language.
- **Folder**: where the agent works.

Changes save as you type. From a task you can also:

- **Run now** to start it straight away.
- **Last run** to open that run's session in Terminal, where you can read it and keep going.
- **Check tools** to confirm the agent's sign-ins and MCP servers are working from that folder.
- **Move to Bin** to delete the task.

The menu also shows your centralOS connection. Hover a server to re-add it, or click **Sign in** when it asks.

**Pause** stops every schedule until you choose **Resume**.

## How it works

Each task is a JSON file in `~/Library/Application Support/AgentScheduler/tasks/` with a LaunchAgent at `~/Library/LaunchAgents/au.centralsoftware.agent-scheduler.<id>.plist`. At the scheduled time, launchd runs `run.sh <id>`. The script pipes the instructions into `claude -p --permission-mode auto --output-format json` from the task's folder.

Each run writes `.json` (result and session), `.err` and `.exit` files to `runs/<id>/`. If the Mac was asleep at the scheduled time, the task runs when it wakes.

## Build from source

```sh
./scripts/make-app.sh            # build/Agent Scheduler.app
./scripts/make-app.sh --install  # install to ~/Applications and launch
./scripts/make-app.sh --zip      # build/Agent-Scheduler-<version>.zip
```

You need Xcode 26 or later. The app icon is an Icon Composer file, which needs that version of `actool`.

| Path | Contents |
| --- | --- |
| `Sources/AgentScheduler/Model.swift` | Value types: tasks, runs, MCP servers, health |
| `Sources/AgentScheduler/Services/` | Stateless access to the shell, the Claude CLI, task files, launchd and system settings |
| `Sources/AgentScheduler/Store.swift` | The observable state, taken from files, launchd and the CLI |
| `Sources/AgentScheduler/Views/` | The menu, the task editor, the launch page and shared components |

See [CHANGELOG.md](CHANGELOG.md) for releases.
