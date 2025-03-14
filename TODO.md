
# WIP

## BUGS


## Introduce the View.

### Alternative

Given the very constrained structure and semantics of View, it may be much simpler not to bother with triple representation and just save the structure. UI is already partly there in terms of the Module selector; just need to add Type selectors and possibly attribute filters, a name field and a Save button ...

### Original

It's like a Module but only one can be active.
It contains:
    - a set of Modules to be loaded (content and style),
    - selectors of Types which filter the Nodes and Links,
    - selectors of attribute values can also act as filters,
    - can also include content and styles.

Syntax to be decided but something like:

```
View : myPicture;
    Using moduleA, moduleB;
    Showing Server, Database, HostedOn;
    language SQL, GraphQL.
```

## Beyond ...

- Sliders for FDL parameters.

- Module deletion.

- Work out how make the Inspector pane act like hyperlinks.
> That will be by matching the attribute value with a Meta.
- E.g.: click on Protocol = http and it applies a filter, highlights matches, or loads "http" module...

- Attributes on types (other than reserved words) could act as proforma for instances.
- Inspector would show unset values from the type. Informative, not mandatory.

- Optimise repulsive forces with octree. (This is an optimisation but should try it on principle.)
- Spatial index for click detection (optimisation). (May be able to use the same octree as for repulsion.)

- Use 3 dimensions for raw triples graph. (Maybe just by random initial distribution.)
- Highlight yellow in module list when waiting for a module to download.

- Tidy the UI. (Collapsible side panes?)
- Collapse edit pane if not editing.

- Report lex and parse errors with line and column.
- Highlight loaded modules that are outdated? -- No, just update them!

- Optimisation - send diffs between back and front ends.

- Add Clockwise and Anticlockwise link alignment fields.
