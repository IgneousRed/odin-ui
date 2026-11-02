# Odin UI

Before editing code, read the installed `coding` skill.
Keep layout, text and interaction independent of raylib, operating systems and application state.
Keep rendering and platform effects in adapters; use caller-owned state.
See `README.md` for the API, ownership and build contracts. Run `scripts/check.sh` after changes.
This library owns no persistent application state or application sessions; example state is disposable.
Exclude the coding skill's application-store, persistence, state-preservation, migration and recovery requirements.
Caller-owned interaction state and frame-local working data still follow the documented ownership and lifetime contracts.
