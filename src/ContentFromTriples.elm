module ContentFromTriples exposing (..)

import Set exposing (..)
import Dict exposing (..)
import DomainModel exposing (..)

{-
    With no concern for efficiency, populate the domain model structures from a set of triples.
    Each set of triples is distinct and forms a separate Module or Diagram.
    I shall focus on Module first and later see how much of a problem are Diagrams.
-}

moduleFromTriples : Set Triple -> Module
moduleFromTriples triples =
    let
        moduleId =
            triples
            |> Set.filter  (\(s,r,o) -> r == "a" && o == "Module")
            |> Set.map (\(s,r,o) -> s)
            |> Set.toList
            |> List.head
            |> Maybe.withDefault "Not a Module"

        label =
            triples
            |> Set.filter  (\(s,r,o) -> s == moduleId && r == "label" )
            |> Set.map (\(s,r,o) -> o)
            |> Set.toList
            |> List.head
            |> Maybe.withDefault "no label found"


        classes =
            triples
            |> Set.filter  (\(s,r,o) -> r == "a" && o == "Type" )
            |> Set.map (\(s,r,o) -> s)
            |> Set.toList
            |> List.map (\s -> (s, {id = s, label = Nothing}))
            |> Dict.fromList

        classesWithLabels =
             triples
             |> Set.foldl
             (\(s,r,o) dict ->
                case (Dict.get s classes, r ) of
                    (Just aClass, "label") ->
                        Dict.insert aClass.id { aClass | label = Just o} dict

                    _ ->
                        dict
             )
             classes



    in

    { id = moduleId
    , label = label
    , sourceFile = Nothing
    , classes = classesWithLabels
    , nodes = Dict.empty
    , links= Dict.empty
    }
