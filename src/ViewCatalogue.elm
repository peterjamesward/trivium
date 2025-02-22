module ViewCatalogue exposing (..)

import Dict exposing (..)
import DomainModel exposing (..)
import Element exposing (..)


showCatalogue : Maybe Module -> Element msg
showCatalogue aModule =
    case aModule of
        Just m ->
            column [ spacing 5, padding 5, width fill ]
                [ showTypes m
                , showNodes m
                , showLinks m
                ]

        Nothing ->
            text "Nothing to show"


showTypes : Module -> Element msg
showTypes m =
    m.classes
        |> Dict.keys
        |> List.map text
        |> wrappedRow [ spacing 5, padding 5, width fill ]


showNodes : Module -> Element msg
showNodes m =
    m.nodes
        |> Dict.keys
        |> List.map text
        |> wrappedRow [ spacing 5, padding 5, width fill ]


showLinks : Module -> Element msg
showLinks m =
    m.links
        |> Dict.keys
        |> List.map text
        |> wrappedRow [ spacing 5, padding 5, width fill ]
