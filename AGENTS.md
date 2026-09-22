# DeepSeek Clock

Native macOS menu bar utility showing whether DeepSeek API
pricing is currently peak or off-peak.

## Stack

- Swift
- SwiftUI
- macOS 13+
- Native APIs preferred
- No backend

## Architecture

Keep business logic separate from UI.

PeakStatusService:
- determines peak/off-peak
- calculates next transition
- operates internally in UTC but follow the user's local timezone for display

MenuBarView:
- presentation only

## DeepSeek Pricing Rules

Monday-Friday UTC:
- 01:00-04:00 = peak
- 06:00-10:00 = peak

Weekends = off-peak.

Never hardcode IST. Convert to the user's local timezone only for display.

## Coding Rules

- Prefer simple native Swift.
- Avoid third-party dependencies unless necessary.
- Do not over-engineer.
- Keep functions small.
- Business logic must be unit testable.

## Testing and CI
Do not run the test suite locally unless explicitly asked.
Tests should run through GitHub Actions CI after changes are pushed to GitHub.
Add or update tests whenever behavior changes, even though they will be executed in CI rather than locally.
Do not remove, weaken, or skip tests just to make CI pass.
If CI fails, inspect the failure, fix the underlying issue, commit the fix, and push again.

## Git Workflow
- Commit extremely frequently.
- Prefer very small atomic commits over larger commits.
- A commit may contain only 1-3 changed lines if those lines form a meaningful logical change.
- Do not wait until an entire feature is complete before committing.
- Whenever a small logical unit of work is complete, stage only that unit and automatically invoke the `git-committer` subagent.
- Do not wait for the user to request a commit.
- Pass the `git-committer` a concise summary and suggested commit message so it does not need to analyze the full diff.


# General Rules
- Treat committing completed logical changes as part of the implementation workflow, not as an end-of-task cleanup step.
