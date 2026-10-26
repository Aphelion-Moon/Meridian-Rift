# Dependency patches

bun applies each patch here to its package on every install, through `patchedDependencies` in
`tgui/package.json`. Make or update one with `bun patch <package>`, edit the files it prints, then
`bun patch --commit node_modules/<package>`.

## tgui-core@6.1.3.patch

bun takes one patch per package version, so this one file holds two fixes, one file diff each. Both are
meant to come from tgui-core itself: when a half is no longer needed, take its file diff out; when neither
is, delete the file and its `patchedDependencies` entry.

### Section.js

`Section` adds its scrollable content to tgui-core's list of scrollable nodes when it mounts, and its
effect's cleanup took the node from its ref to remove it again. React has already cleared that ref when
the cleanup of an unmounting component runs, so nothing was ever removed: every scrollable Section that
left the page stayed in the list for the life of the window, with everything under it. In character
setup that was about 1,900 DOM nodes and 650 listeners each time the Loadout tab was left, and the list
is also walked on every mouse move. The patch has the cleanup remove the node the effect added.

Drop this half once a tgui-core release has the fix (tgui-core#277, merged after 6.1.3).

### Image.js

`Image` with `fixErrors` tries a failed `src` again a second later, as `src?attempt=N`, up to five
times. A `src` that already had a query (every DmIcon's does) got a second `?`, which broke its last
parameter; a retry still waiting when `src` changed wrote the old icon over the new one; and every error
while a retry waited started another timer. The patch only changes `onError`, so a healthy image costs
what it did: one retry waits at a time, it gives up if `src` moved on, a new `src` gets its own five,
and `attempt` goes in with `&` after an existing query, before any `#fragment`.

Drop this half once tgui-core has an equivalent fix.
