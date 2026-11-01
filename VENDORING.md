# Copy Odin UI into your project

Download `odin_ui-v0.1.1.zip` from the
[v0.1.1 release](https://github.com/IgneousRed/odin-ui/releases/tag/v0.1.1).
Extract its `odin_ui/` folder into your project's `vendor/` directory:

```text
my-game/
├── src/
│   └── main.odin
└── vendor/
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
`src/`, plus `LICENSE` and `VERSION`, into `vendor/odin_ui/`. You can copy
this guide there as `README.md` too. Commit the copied files to your own Git
repository. Consumers need no library-specific build scripts or downloads.

From `src/main.odin`, import the packages relative to that file:

```odin
import ui "../vendor/odin_ui/raylib"
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
odin build src -collection:odin_ui=vendor/odin_ui
```

Then use `import ui "odin_ui:raylib"` (or `odin_ui:layout`, `odin_ui:text`,
`odin_ui:input`). Relative imports need no collection flag.

For a project with multiple build commands, put the collection flag in its
build helper so native builds, web builds and tests resolve the same copy. Point
development file watching at `vendor/odin_ui/` as well. Keep the library's MIT
license in that directory and include it with redistributed application builds.

## Updating your copy

`VERSION` records the release and source URL. Releases in the `0.x` series may
change the API; read the release notes before updating.

Choose a specific release tag for each update. Normal builds use the committed
copy and do not download updates. To upgrade, read the release notes, download
the chosen ZIP and `SHA256SUMS.txt`, and verify the ZIP before extracting it:

```sh
# Run in the directory containing the downloaded ZIP and checksum file.
shasum -a 256 -c SHA256SUMS.txt
```

Keep your local modifications committed. Extract the new release separately,
compare it with your current copy, merge your modifications, and replace the
old directory with the merged result. Remove files deleted by the new release
rather than just copying new files over old ones. Update `VERSION` and run your
application's checks before committing the upgrade. Retain `LICENSE` with all
copies; Odin UI is MIT licensed, including commercial use.

Prefer application-specific wrappers outside `vendor/odin_ui/`. Make reusable
library fixes in Odin UI's source repository and consume a tagged release of
those changes. This keeps each project's dependency update easy to review.
