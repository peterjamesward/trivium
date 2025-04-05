# elm-3d-scene and Lamdera

I have a FrontendModel with a graphic component built using elm-3d-scene, an awesome library that allows creation of 3d scenes without needing to master WebGL. elm-3d-scene's author Ian Mackenzie advises to construct the scene (the "mesh") in `update`. This will generally combine the elm-3d-scene primitives such as block, cone, cube & sphere.

My FrontendModel specifically contains a 3d scene to be rendered.

```elm
    , scene : List (Entity WorldCoordinates)
```

This is a problem for `lamdera check`:

```shell
I ran into the following problems when checking Lamdera core types:

FrontendModel:

- must not contain functions: TType (Module.Canonical (Name "elm-explorations" "linear-algebra") "Math.Matrix4") "Mat4" []
TLambda (TType (Module.Canonical (Name "elm-explorations" "linear-algebra") "Math.Vector4") "Vec4" []) (TLambda (TType (Module.Canonical (Name "elm-explorations" "linear-algebra") "Math.Matrix4") "Mat4" []) (TLambda (TType (Module.Canonical (Name "elm" "core") "Basics") "Bool" []) (TLambda (TType (Module.Canonical (Name "elm-explorations" "linear-algebra") "Math.Matrix4") "Mat4" []) (TLambda (TType (Module.Canonical (Name "elm-explorations" "linear-algebra") "Math.Matrix4") "Mat4" []) (TLambda (TType (Module.Canonical (Name "elm-explorations" "linear-algebra") "Math.Matrix4") "Mat4" []) (TLambda (TType (Module.Canonical (Name "elm" "core") "List") "List" [TAlias (Module.Canonical (Name "elm-explorations" "webgl") "WebGL.Settings") "Setting" [] (Filled (TType (Module.Canonical (Name "elm-explorations" "webgl") "WebGL.Internal") "Setting" []))]) (TType (Module.Canonical (Name "elm-explorations" "webgl") "WebGL") "Entity" [])))))))
```

Not the kind of error message we expect from Elm, but the gist is that our model cannot contain a partially evaluated function.

We display our scene in the `view` by calling `unlit`, `cloudy`, or `sunny`:

```elm
unlit :
    { dimensions : ( Quantity Int Pixels, Quantity Int Pixels )
    , camera : Camera3d Meters coordinates
    , clipDepth : Length
    , background : Background coordinates
    , entities : List (Entity coordinates)
    }
    -> Html msg
```

Here is our problem. These combine the camera position with the mesh which is encoded in the `entities` as `List (Entity coordinates)`, and unpacking a few levels of type, we find:

```elm
    | MeshNode Bounds (DrawFunction ( LightMatrices, Vec4 ))
```

where 

```elm
type alias DrawFunction lights =
    Mat4 -- scene properties
    -> Vec4 -- model scale
    -> Mat4 -- model matrix
    -> Bool -- model matrix is right-handed
    -> Mat4 -- view matrix
    -> Mat4 -- projection matrix
    -> lights -- lights
    -> List WebGL.Settings.Setting -- stencil, depth, blend etc.
    -> WebGL.Entity
```

which is the source of the unwieldy error message.

So the practice recommended by the package author is not workable. (It's a tad annoying that it works in local mode and this limitation only arises during `lamdera check` but perhaps a thorough read of the docs would have avoided that.)

What choices do I have now?

1. Move the rendering into `update` and just include the result in `view`.
2. Move the mesh building into `view` contrary to advice (and probably unwise for performance).

I tried option 1. I enjoy refactoring in Elm more than any other language I have used. Just replace `List (Entity coordinates)` with whatever `unlit` returns.

```elm
unlit :
    { dimensions : ( Quantity Int Pixels, Quantity Int Pixels )
    , camera : Camera3d Meters coordinates
    , clipDepth : Length
    , background : Background coordinates
    , entities : List (Entity coordinates)
    }
    -> Html msg
```

Hence my model now has

```elm
    , renderedScene : Html msg
```

but `lamdera check` says:

```shell
I ran into the following problems when checking Lamdera core types:

FrontendModel:

- must not contain kernel type `Node` from elm/virtual-dom:VirtualDom
```

Not likely to work. That leaves the undesirable "do it all in the view" option, or the inevitable:

3. Think of something else that might not upset Lamdera.

Can I tell Lamdera to stop worrying about schema evolution? I can -- `lamdera check --destructive-migration`!

Reverting back to the original code base and trying this leaves me staring at the same original error -

```shell
I ran into the following problems when checking Lamdera core types:

FrontendModel:

- must not contain functions: TType (Module.Canonical (Name "elm-explorations" "linear-algebra") "Math.Matrix4") "Mat4" []
...
```

My problem now is that, essentially, Lamdera is a problem. Not all of it, but certainly this constraint on what I can put into my Frontend model. I don't actually _care_ about bing able to do evergreen migrations. Backend, maybe, not Frontend. I'm happy to have to reload my browser or something and lose front end state.


