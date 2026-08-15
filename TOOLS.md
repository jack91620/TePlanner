# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

### Things 3 (macOS)

- **Status:** Not configured.
- **Issue:** The `things` CLI tool requires the path to the local Things database. The location could not be determined automatically. Before using this tool, the correct path to `main.sqlite` needs to be found and provided using the `--db` flag or by setting the `THINGSDB` environment variable.

### Calendar (macOS)

- **Status:** Not configured.
- **Issue:** To check your calendar, I need a command-line tool. I tried using `icalbuddy`, but it doesn't seem to be installed. If you'd like me to check your calendar for upcoming events, you can install it by running `brew install ical-buddy`.

### Email (macOS)

- **Status:** Not configured.
- **Issue:** I don't have a way to check your email. If you'd like me to be able to read your latest emails, you'll need to install and configure a command-line email client.

