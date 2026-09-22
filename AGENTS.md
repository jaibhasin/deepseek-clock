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
Commit frequently.
Local commits are encouraged even for small meaningful changes.
Make git messages clear and descriptive without adding unnecessary verbosity and co-authorship.
Prefer many small, focused commits over large commits containing unrelated changes.
Create commits even for small but meaningful changes.
Each commit should represent one logical change.
Keep giignore files up to date.
