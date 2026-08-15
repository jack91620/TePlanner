
- **TePlanner Project:**
    - **Remote Repository:** `git@github.com:jack91620/TePlanner.git` (must use SSH)
    - **Branching:** Primary work is done on the `ios-development` branch.
    - **Architecture:** The iOS project uses Swift Package Manager (SPM). Core logic is in the `TePlannerKit` library target to manage module visibility.
    - **Workflow:**
        - I write code and tests.
        - The user runs tests locally in Xcode due to a `no such module 'XCTest'` error in my execution environment.
        - User handles creating the initial `.xcodeproj` file and other GUI-dependent tasks.
