
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

or TTL like:

blueCube a Style; colour blue; shape cube.
someLink a Style; colour green; direction east.
a a Node; style blueCube; label "my first node".
b a Node; style orangeSphere; label "another thing".
ab a Link; from a; to b: label "something..."; style someLink.

I think TTL has this; only the Link feels mre awkward, lacking the immediacy of "a -> b".
But that's not insurmountable, we could have

a -> b a Link ...
we would have to use the lexer to make "a -> b" into a single token, with caveats for uniqueness.
(This looks less problematic)

Better imho, and more like what I have is:

blueCube a Style; colour blue; shape cube.
someLink a Style; colour "0x4020F0"; direction east.
server a Type; style blueCube.
database a Type.
uses a Link; style someLink.
a a server; label "my first node".
b a database; label "another thing".
a uses b.

The only change here is the "uses", which is a "Link". Nice.
Can add semantics to link:
a uses b; format SQL; protocol postgres; frequency ad-hoc.

Using "imposed keyword semantics", like D2, makes our life easier!
Lexer stays the same. Triples are things. Semantics much easier.