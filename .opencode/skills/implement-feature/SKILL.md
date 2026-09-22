---
name: implement-feature
description: Use when implementing a new feature or changing existing behavior in DeepSeek Clock.
---

1. Read AGENTS.md.
2. Read docs/PRODUCT.md if the feature affects product behavior.
3. Inspect existing relevant code before editing.
4. Prefer the smallest implementation that solves the requirement.
5. Keep business logic separate from SwiftUI views.
6. Add or update tests for behavior changes.
7. Do not run the full test suite locally.
8. Review the diff for unnecessary changes.
9. Update docs/PRODUCT.md if the feature affects product behavior and let user know succinctly what changed.