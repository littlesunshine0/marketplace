# Accessibility & Localization Scan

- Verified primary views (`InventoryView`, `OrdersView`, `SettingsView`) use `NavigationStack` titles and `Label` for voice over clarity.
- Button labels are explicit (e.g., "Connect New Account", "Publish"); no icon-only controls.
- Text content sourced from SwiftUI `Text` allowing Dynamic Type; no fixed-size fonts.
- Localization-ready strings: user-facing copy placed in string literals consolidated for future `Localizable.strings` export.
- Color usage relies on system defaults for light/dark mode compatibility.
