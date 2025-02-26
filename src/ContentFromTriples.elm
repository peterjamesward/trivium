module ContentFromTriples exposing (..)

import Dict exposing (..)
import DomainModel exposing (..)
import Set exposing (..)
import Types exposing (..)



{-
   Populate domain model structures from a set of triples.
   Each set of triples is distinct and forms a separate Module or Diagram.
   I shall focus on Module first and later see how much of a problem are Diagrams.
-}


type alias Indexes =
    { subjectRelationIndex : OuterDict -- facts about each subject
    , objectRelationIndex : OuterDict -- facts about each object
    , relationObjectIndex : OuterDict -- Surprisingly useful as gives us our type membership for free.
    }


moduleFromTriples : Set Triple -> Module
moduleFromTriples triples =
    let
        -- Indexing triples should make semantic extraction easier.
        emptyIndexes =
            { subjectRelationIndex = Dict.empty
            , objectRelationIndex = Dict.empty
            , relationObjectIndex = Dict.empty
            }

        indexes =
            triples |> Set.foldl indexTriple emptyIndexes

        indexTriple : Triple -> Indexes -> Indexes
        indexTriple ( s, r, o ) indxs =
            { indxs
                | subjectRelationIndex = addToDoubleIndex s r o indxs.subjectRelationIndex
                , objectRelationIndex = addToDoubleIndex o r s indxs.objectRelationIndex
                , relationObjectIndex = addToDoubleIndex r o s indxs.relationObjectIndex
            }

        addToDoubleIndex : String -> String -> String -> OuterDict -> OuterDict
        addToDoubleIndex a b c outerDict =
            let
                innerDict =
                    Dict.get a outerDict |> Maybe.withDefault Dict.empty

                set =
                    Dict.get b innerDict |> Maybe.withDefault Set.empty

                newInner =
                    Dict.insert b (Set.insert c set) innerDict
            in
            Dict.insert a newInner outerDict

        fromIndexN : String -> String -> OuterDict -> Set String
        fromIndexN outerKey innerKey outerDict =
            case Dict.get outerKey outerDict of
                Just innerDict ->
                    Dict.get innerKey innerDict |> Maybe.withDefault Set.empty

                Nothing ->
                    Set.empty

        fromIndex1 : String -> String -> OuterDict -> Maybe String
        fromIndex1 outerKey innerKey outerDict =
            fromIndexN outerKey innerKey outerDict
                |> Set.toList
                |> List.head

        moduleId =
            fromIndex1 "Module" "label" indexes.subjectRelationIndex
                |> Maybe.withDefault "unnamed"

        moduleLabel =
            fromIndex1 moduleId "label" indexes.subjectRelationIndex
                |> Maybe.withDefault ""

        allUsedClasses : Dict ClassId Class
        allUsedClasses =
            -- If "a is b" then b is an implicit type, but careful in case already is explicit.
            -- The joy is that we get all the membership here thanks to the index.
            -- Also, we can use it to give us the explicit types ("z is Type.")
            Dict.get "is" indexes.relationObjectIndex
                |> Maybe.withDefault Dict.empty
                |> Dict.map
                    (\id members ->
                        { id = id
                        , label = fromIndex1 id "label" indexes.subjectRelationIndex
                        , nodeIds = members
                        }
                    )

        declaredButUnusedClasses =
            -- Make a class record for any type that was declared but not used.
            case Dict.get "Type" allUsedClasses of
                Just declaredClasses ->
                    declaredClasses.nodeIds
                        |> Set.filter (\classId -> not <| Dict.member classId allUsedClasses)
                        |> Set.toList
                        |> List.map
                            (\classId ->
                                ( classId
                                , { id = classId
                                  , label = fromIndex1 classId "label" indexes.subjectRelationIndex
                                  , nodeIds = Set.empty
                                  }
                                )
                            )
                        |> Dict.fromList

                Nothing ->
                    Dict.empty

        nodeIds : Set NodeId
        nodeIds =
            -- OK. Nodes. Generally, these would be declared explicitly, so the subjectRelationIndex
            -- is our main source. However, I would like to allow `a -> b x y.` to be a valid
            -- and sufficient input. This means we need to look at _FROM and _TO on all the links.
            -- Luckily, we can do that almost trivially from the relationObjectIndex :)
            -- We exclude reified links, identified by the leading underscores "__".
            Set.union explicitNodeIds implicitNodeIds

        explicitNodeIds : Set NodeId
        explicitNodeIds =
            indexes.subjectRelationIndex
                |> Dict.keys
                |> List.filter (\id -> not <| String.startsWith "__" id)
                |> Set.fromList

        implicitNodeIds : Set NodeId
        implicitNodeIds =
            let
                fromNodeIds =
                    Dict.get "__FROM" indexes.relationObjectIndex
                        |> Maybe.withDefault Dict.empty
                        |> Dict.keys
                        |> Set.fromList

                toNodeIds =
                    Dict.get "__TO" indexes.relationObjectIndex
                        |> Maybe.withDefault Dict.empty
                        |> Dict.keys
                        |> Set.fromList
            in
            Set.union fromNodeIds toNodeIds

        nodes : Dict NodeId Node
        nodes =
            nodeIds
                |> Set.filter (\id -> not <| Dict.member id allUsedClasses)
                |> Set.filter (\id -> id /= moduleId)
                -- special case.
                |> Set.toList
                |> List.map (\id -> ( id, buildNode id ))
                |> Dict.fromList

        buildNode : NodeId -> Node
        buildNode id =
            --TODO: or implicit typing.
            --Note we only surface one value for any attribute.
            { id = id
            , label = fromIndex1 id "label" indexes.subjectRelationIndex
            , class = fromIndex1 id "is" indexes.subjectRelationIndex
            , attributes =
                Dict.get id indexes.subjectRelationIndex
                    |> Maybe.withDefault Dict.empty
                    |> Dict.filter
                        (\relation objects ->
                            not <| Set.member relation (Set.fromList [ "is", "label" ])
                        )
            }

        links =
            -- Links, in this new world, are explicit and we can find them by their "__FROM"
            -- or we can just look for nodes that start with "__", which is clearer if less efficient.
            indexes.subjectRelationIndex
                |> Dict.filter (\id content -> String.startsWith "__" id)
                |> Dict.map buildLink

        buildLink : NodeId -> InnerDict -> Link
        buildLink anon inner =
            { linkId = anon
            , fromNode = fromIndex1 anon "__FROM" indexes.subjectRelationIndex |> Maybe.withDefault ""
            , toNode = fromIndex1 anon "__TO" indexes.subjectRelationIndex |> Maybe.withDefault ""
            , label = fromIndex1 anon "label" indexes.subjectRelationIndex |> Maybe.withDefault ""
            , class = fromIndex1 anon "is" indexes.subjectRelationIndex
            , attributes =
                inner
                    |> Dict.filter
                        (\relation objects ->
                            not <| Set.member relation (Set.fromList [ "is", "label", "__FROM", "__TO" ])
                        )
            }

        classes =
            Dict.union allUsedClasses declaredButUnusedClasses
                |> Dict.filter
                    (\id class ->
                        -- Remove reserved words.
                        not <| Set.member id (Set.fromList [ "Type", "Module" ])
                    )
    in
    { id = moduleId
    , label = moduleLabel
    , sourceFile = fromIndex1 moduleId "source" indexes.subjectRelationIndex
    , classes = classes
    , nodes = nodes
    , links = links
    }
