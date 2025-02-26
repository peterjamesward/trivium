module AsText exposing (moduleToText)

import Dict exposing (..)
import DomainModel exposing (..)
import Set exposing (..)
import String.Interpolate exposing (interpolate)


moduleToText : Module -> String
moduleToText m =
    moduleHeader m
        ++ withClasses m.classes
        ++ withNodes m.nodes
        ++ withLinks m.links


moduleHeader m =
    -- Canonical form.
    "Module : " ++ m.id ++ """.

"""


withClasses : Dict ClassId Class -> String
withClasses classes =
    let
        attribute : String -> Set String -> String
        attribute relation objects =
            String.concat
                [ "; "
                , relation
                , " "
                , objects |> Set.toList |> String.join """, 
    """
                ]

        phrases : Class -> String
        phrases class =
            (Dict.map attribute class.attributes |> Dict.values)
                |> String.join """;
"""
    in
    classes
        |> Dict.values
        |> List.map
            (\class ->
                class.id
                    ++ " is Type"
                    ++ (case class.label of
                            Just label ->
                                """;
    label """
                                    ++ label

                            Nothing ->
                                ""
                       )
                    -- Elide nodes with nothing useful to say.
                    ++ phrases class
                    ++ """ .
"""
            )
        |> String.join """"""


withNodes : Dict NodeId Node -> String
withNodes nodes =
    let
        attribute : String -> Set String -> String
        attribute relation objects =
            String.concat
                [ " "
                , relation
                , " "
                , objects |> Set.toList |> String.join """, 
    """
                ]

        phrases : Node -> String
        phrases node =
            (([ Maybe.map (\class -> " is " ++ class) node.class
              , Maybe.map (\label -> " label " ++ label) node.label
              ]
                |> List.filterMap identity
             )
                ++ (Dict.map attribute node.attributes |> Dict.values)
            )
                |> String.join """;
"""
    in
    nodes
        |> Dict.filter (\id _ -> id /= "Module")
        |> Dict.values
        |> List.filterMap
            (\node ->
                -- Elide nodes with nothing useful to say.
                case phrases node of
                    "" ->
                        Nothing

                    somePhrases ->
                        Just <| node.id ++ somePhrases ++ " ."
            )
        |> String.join """
"""


withLinks : Dict LinkId Link -> String
withLinks links =
    let
        attribute : String -> Set String -> String
        attribute relation objects =
            "    "
                ++ relation
                ++ " "
                ++ (objects |> Set.toList |> String.join """, 
            """)

        phrases : Link -> String
        phrases link =
            (([ Just
                    (link.fromNode
                        ++ " -> "
                        ++ link.toNode
                        ++ " : "
                        ++ link.label
                    )
              , Maybe.map (\class -> " is " ++ class) link.class
              ]
                |> List.filterMap identity
             )
                ++ (Dict.map attribute link.attributes |> Dict.values)
            )
                |> String.join """;
"""
    in
    (links
        |> Dict.values
        |> List.map phrases
        |> String.join """.
"""
    )
        ++ (if Dict.isEmpty links then
                ""

            else
                """.
"""
           )


safely : String -> String
safely using =
    if List.length (String.words using) > 1 then
        "\"" ++ using ++ "\""

    else
        using
