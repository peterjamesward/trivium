
# WIP

## BUGS

## Changes

Use uppercase initial for all reserved words - direction, shape, colours etc.
Introduce a new linear force to keep things above the ground plane.

## Introduce the View.

- Choose a named View.
- Delete a View.

## Beyond ...

- Planar v 3d option for initial placement. (Use grid or cube.)
- Sliders for FDL parameters.

- Module deletion.

- Work out how make the Inspector pane act like hyperlinks.
> That will be by matching the attribute value with a named View (???).
- E.g.: click on Protocol = http and it applies a filter, highlights matches, or loads "http" module...

- Attributes on types (other than reserved words) could act as proforma for instances.
- Inspector would show unset values from the type. Informative, not mandatory.

- Optimise repulsive forces with octree. (This is an optimisation but should try it on principle.)
- Spatial index for click detection (optimisation). (May be able to use the same octree as for repulsion.)

- Highlight yellow in module list when waiting for a module to download.

- Tidy the UI. (Collapsible side panes?)
- Collapse edit pane if not editing.

- Report lex and parse errors with line and column.
- Highlight loaded modules that are outdated? -- No, just update them!

- Optimisation - send diffs between back and front ends.

- Add Clockwise and Anticlockwise link alignment fields.
