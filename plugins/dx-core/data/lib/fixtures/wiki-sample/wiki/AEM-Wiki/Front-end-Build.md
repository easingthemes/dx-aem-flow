# Front-end Build

## Clientlib bundling

The front-end module compiles SCSS and TypeScript with webpack and copies the output into clientlibs. Run the full Maven build; the front-end build alone does not deploy anything.

## Common failures

A failing build usually means a Node version mismatch. Use the version pinned in the project file. Clear the node cache before reporting a broken pipeline.
