# Copy Odin UI into your project

Download `odin_ui-v0.1.0.zip` from the
[v0.1.0 release](https://github.com/IgneousRed/odin-ui/releases/tag/v0.1.0).
Extract its `odin_ui/` folder into your project's `third_party/` directory:

```text
my-game/
├── src/
│   └── main.odin
└── third_party/
    └── odin_ui/
        ├── layout/
        ├── text/
        ├── input/
        ├── raylib/
        ├── LICENSE
        ├── VERSION
        └── README.md
```

Alternatively, download the tagged repository source and copy the contents of
`src/`, plus `LICENSE` and `VERSION`, into `third_party/odin_ui/`. You can copy
this guide there as `README.md` too. Commit the copied files to your own Git
repository. Consumers need no library-specific build scripts or downloads.

From `src/main.odin`, import the packages relative to that file:

```odin
import ui "../third_party/odin_ui/raylib"
```

Build your application normally, for example `odin build src`. The `raylib`
adapter also needs Odin's `vendor:raylib` bindings and the platform's raylib
linking setup. You supply the window, main loop, fonts and persistent state.
The [repository README](https://github.com/IgneousRed/odin-ui#checks-and-showcase)
lists the tested toolchain and a complete showcase host.

The `layout`, `text` and `input` packages use only Odin core libraries. Copy all
three together for a renderer-independent installation; omit `raylib/` if you
do not use that adapter. All internal imports are relative, so keep these
package folders together when moving or renaming the library directory.

If you prefer collection imports, build from your project root with:

```sh
odin build src -collection:odin_ui=third_party/odin_ui
```

Then use `import ui "odin_ui:raylib"` (or `odin_ui:layout`, `odin_ui:text`,
`odin_ui:input`). Relative imports need no collection flag.

## Updating your copy

`VERSION` records the release and source URL. Releases in the `0.x` series may
change the API; read the release notes before updating.

Keep your local modifications committed. Extract the new release separately,
compare it with your current copy, merge your modifications, and replace the
old directory with the merged result. Remove files deleted by the new release
rather than just copying new files over old ones. Update `VERSION` and run your
application's checks before committing the upgrade. Retain `LICENSE` with all
copies; Odin UI is MIT licensed, including commercial use.
