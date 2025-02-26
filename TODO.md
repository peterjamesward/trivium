
# WIP

- Make sure that failed parse disables Save button.
- Render in 3D. (Need to recreate the field forces for links.)
- SVG overlay

- Report lex and parse errors with line and column.
- Use time as seed for reified node id.
- Allow selection of multiple Modules.
- Allow selection of one Diagram.
- Overhaul the UI.
- Make multiple tabs in main window (input | output).
- Option to show all triples as "non-semantic" graph.

- Add Inspector pane.
- Save to file.
- File load.
- Keep list of files loaded.
- Select and edit a file.
- Select files to show (in each window).
- Select styles to apply (per window).
- Add basic inspector.

- Add Clockwise and Anticlockwise link alignment fields.

# Discussion

Have abandoned the idea of being able to round trip a D2 file. Their approach to keywords is a problemm.
But could use their notation as a better way to do rich (reified) links.
Could just go with JSON, or something slightly more D2 & user-friendly, but not interoperable.
Very regular grammar, easy to lex and parse, is the key.

e.g. D2-like:

```
styles : {
    blueCube : {
        colour : blue
        shape : cube
    }
    someLink : {
        colour : green
        direction : east
    }
}
a : my first node {
    style : blueCube
}
b : another thing {
    style : orangeSphere
}
a -> b : something happens here {
    style : someLink
}
```

or TTL like:

```
blueCube a Style; colour blue; shape cube.
someLink a Style; colour green; direction east.
a a Node; style blueCube; label "my first node".
b a Node; style orangeSphere; label "another thing".
ab a Link; from a; to b: label "something..."; style someLink.
```

I think TTL has this; only the Link feels mre awkward, lacking the immediacy of "a -> b".
But that's not insurmountable, we could have

a -> b a Link ...
we would have to use the lexer to make "a -> b" into a single token, with caveats for uniqueness.
(This looks less problematic)

Better imho, and more like what I have is:

```
blueCube a Style; colour blue; shape cube.
someLink a Style; colour "0x4020F0"; direction east.
server a Type; style blueCube.
database a Type.
uses a Link; style someLink.
a a server; label "my first node".
b a database; label "another thing".
a uses b.
```

The only change here is the "uses", which is a "Link". Nice.
Can add semantics to link:
`a uses b; format SQL; protocol postgres; frequency ad-hoc.`

NB, this does NOT work because these are not statements about 'a'.

This problem vanishes if we discard the concept of independent triples, and have
a "sentence scope" rule. The last statement is then four assertions scoped in 
the single sentence. It also permits:

`adam begat cain, abel; mother eve; location eden.`

Again, no. How do I know when I'm talking about 'adam' or about the 'begat' link?
It's perhaps clearer, in more than one way, to use a special symboi "->" which is
visibly a link and can then override the node-oriented semantics.

`adam -> cain; with eve; location eden; label father.`

This, I think I can still reify. 
But why the obsession with triples Peter? 
Because, semantics.
It works because `adam -> cain`, whilst looking like a triple, is actually 
a single "link" thing. It's like saying

`(adam -> cain) is link; with eve; ...`, but avoids the parentheses.

Using "imposed keyword semantics", like D2, makes our life easier!
Lexer stays the same. Triples are things. Semantics much easier.

Reserved words (so far):
- a
- Style (colour, shape, direction)
- colour (red, orange, ..)
- shape  (cube, sphere, cylinder, cone, ..)
- Type 
- Link 
- direction (N,S,E,W,U,D)
- label 
- Module
- Layout
- Diagram
- style (binding)

May need some more when we think about defining a projection/selection/diagram. Certainly want the 'binding' between type/class and style not to be defined in the model, but in the view.
E.g.:

```
funky a Diagram;
    contains Server, Database; -- i.e. "all nodes of these types"
    using writes, reads; -- "all links of these types"
    showing protocol;   -- "use this for link label?"
    adopting thisStyle, thatStyle; -- "doesn't work; need to associate with Types"
    layout force3d. -- "yes".
```

(See below about Module and Layout).

This line of thought makes me think that it should be easier to assemble a diagram from
the smaller components ("quanta"); that these diagrams, just collections of instances,
not necessarily defined only by type. But more they also each have a database entry, perhaps
each has its owne versioning even, and a diagram is like a package dependency with version
constraints (e.g. latest, <=5.1, ==4.3.2).

I see no need at this moment for quoted strings, so I will drop those, or keep them for labels but not really treat them as special. So we can use "Pete 🤷‍♂️" as a node, link or anything. The quotes are needed for the space here! 
If we insist on triple-quoted strings, we can probably avoid need for escaping.

Anyway, let's have a "database", with parts for:
- Nodes
- Links
- Types (node and link)
- Styles
- Diagrams.

We can have one big window that has two modes:
1. Navigate database, see the current text, edit it, add new elements, track versions.
2. The force3d view, with option to switch between Diagrams and Styles.

With Lamdera, can trivially open as many windows as we want.
Question: do we also want "Project" as a concept and if so, are they segregated or is content exchangable?
Answer: "Project" would be a collaboration space. If you want separation, make a new instance of the app.

Make Module a reserved word. Each file will be a module:

```local_network a Module.```

When we upload a file, the Module name appears in the Module dictionary.
We tick which modules we want to see in a diagram, then filter by type.
I see the image viewer as having perhaps a left hand collapsible with the Module and Type selectors,
possibly also the Type-Style binding. Right hand collapsible Inspector.

Diagram can be like Modules but they are about visuals not content. They can contain
filters, styles, or they can bind to any styles in the working set (by name).

```topology a Diagram
    with Network, Server, Router, Switch;
    with Connection.

Person style PersonStyle.
Place style BuildingStyle.
````