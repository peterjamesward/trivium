module DiagramAsText exposing (diagramAsText)

import Dict exposing (..)
import DomainModel exposing (..)


diagramAsText : Diagram -> String
diagramAsText diagram =
    let
        classesString =
            diagram.classes
                |> Dict.values
                |> List.map writeClass
                |> String.join ".\n"

        nodesString =
            diagram.nodes
                |> Dict.values
                |> List.map writeNode
                |> String.join ".\n"

        linksString =
            diagram.links
                |> Dict.values
                |> List.map writeLink
                |> String.join ".\n"

        writeClass : Class -> String
        writeClass class =
            class.id
                ++ " a Class; label "
                ++ class.label

        writeNode : Node -> String
        writeNode node =
            node.id
                ++ (case node.class of
                        Just class ->
                            -- Let the class dominate
                            " a "
                                ++ class
                                ++ ";\n label "

                        Nothing ->
                            -- Skip to label
                            " label "
                   )
                ++ node.label
                ++ ";\n"
                ++ writeAttributes node.attributes

        writeLink : Link -> String
        writeLink link =
            link.fromNode
                ++ " -> "
                ++ link.toNode
                ++ (case link.class of
                        Just class ->
                            -- Let the class dominate
                            " a "
                                ++ class
                                ++ ";\n label "

                        Nothing ->
                            -- Skip to label
                            " label "
                   )
                ++ link.label
                ++ ";\n"
                ++ writeAttributes link.attributes

        writeAttributes : Dict String String -> String
        writeAttributes attributes =
            (attributes
                |> Dict.toList
                |> List.map
                    (\( key, value ) ->
                        "  " ++ key ++ " " ++ value
                    )
                |> String.join ";\n"
            )
                ++ ".\n"
    in
    classesString ++ nodesString ++ linksString
