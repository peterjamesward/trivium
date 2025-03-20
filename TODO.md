
# BUGS

# WIP

- Toggling visibility should not destroy layout.
> This needs something akin to `computeInitialPositions' but
> is more `computePositionsForNewContent`.

- Delete a View.
- Module deletion.

- Planar v 3d option for initial placement. (Use grid or cube.)

- Work out how make the Inspector pane act like hyperlinks.
> That will be by matching the attribute value with a named View (???).
- E.g.: click on Protocol = http and it applies a filter, highlights matches, or loads "http" module...

- Optimise repulsive forces with octree. (This is an optimisation but should try it on principle.)
- Spatial index for click detection (optimisation). (May be able to use the same octree as for repulsion.)

- Attributes on types (other than reserved words) could act as proforma for instances.
- Inspector would show unset values from the type. Informative, not mandatory.

- Highlight yellow in module list when waiting for a module to download.

- Tidy the UI. (Collapsible side panes?)
- Collapse edit pane if not editing.

- Report lex and parse errors with line and column.
- Highlight loaded modules that are outdated? -- No, just update them!

- Optimisation - send diffs between back and front ends?

- Add Clockwise and Anticlockwise link alignment fields.
- Add force to move stuff above ground plane.
- Sliders for FDL parameters.
