
# WIP

- Render as D2.
- Render in 3D.
- Add basic inspector.

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

Using "imposed keyword semantics", like D2, makes our life easier!
Lexer stays the same. Triples are things. Semantics much easier.

Reserved words (so far):
- a
- Style
- colour (red, orange, ..)
- shape  (cube, sphere, cylinder, cone, ..)
- Type 
- Link 
- direction (..)
- label 

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

This line of thought makes me think that it should be easier to assemble a diagram from
the smaller components ("quanta"); that these diagrams, just collections of instances,
not necessarily defined only by type. But more they also each have a database entry, perhaps
each has its owne versioning even, and a diagram is like a package dependency with version
constraints (e.g. latest, <=5.1, ==4.3.2).

I see no need at this moment for quoted strings, so I will drop those, or keep them for labels but not really treat them as special. So we can use "Pete 🤷‍♂️" as a node, link or anything. The quotes are needed for the space here!

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
