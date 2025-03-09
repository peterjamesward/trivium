
# WIP

## Introduce the Meta.
It's like a Module but only one can be active.
It contains:
    - a set of Modules to be loaded (content and style),
    - selectors of Types which filter the Nodes and Links,
    - selectors of attribute values can also act as filters,
    - can also include content and styles.

Syntax to be decided but something like:
```
Meta : myPicture.
Filter Type Server, Database;
 language SQL.
HostedOn is Type; direction south.
```

- Work out how make the Inspector pane act like hyperlinks.
> That will be by matching the attribute value with a Meta.
- E.g.: click on Protocol = http and it applies a filter, highlights matches, or loads "http" module...

- Optimise repulsive forces with octree. (This is an optimisation but should try it on principle.)
- Use 3 dimensions for raw triples graph. (Maybe just by random initial distribution.)
- Highlight yellow in module list when waiting for a module to download.

- Tidy the UI. 
- Collapse edit pane if not editing.

- Report lex and parse errors with line and column.
- Highlight loaded modules that are outdated.
- Optimisation - send diffs between back and front ends.

- Add Clockwise and Anticlockwise link alignment fields.
- Spatial index for click detection (optimisation). (May be able to use the same octree as for replusion.)
