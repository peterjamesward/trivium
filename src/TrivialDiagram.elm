module TrivialDiagram exposing (..)

import Dict exposing (..)
import DomainModel exposing (..)
import Set exposing (..)


diagram : D2Diagram
diagram =
    { id = "DEMO"
    , classes =
        Dict.fromList
            [ ( nodeClass.id, nodeClass )
            , ( linkClass.id, linkClass )
            ]
    , nodes =
        Dict.fromList
            [ ( aNode.id, aNode )
            , ( bNode.id, bNode )
            ]
    , links = Dict.singleton ( aNode.id, bNode.id ) abLink
    }


nodeClass : D2Class
nodeClass =
    { id = "orangeSphere"
    , attributes =
        Dict.fromList
            [ ( "colour", "orange" )
            , ( "shape", "sphere" )
            ]
    }


linkClass : D2Class
linkClass =
    { id = "blueLink"
    , attributes =
        Dict.fromList
            [ ( "colour", "blue" )
            ]
    }


aNode : D2Node
aNode =
    { id = "a"
    , label = "A"
    , class = Just nodeClass.id
    , attributes = Dict.empty
    , containedNodes = Set.empty
    , enclosingNode = Nothing
    }


bNode : D2Node
bNode =
    { id = "b"
    , label = "B"
    , class = Just nodeClass.id
    , attributes = Dict.empty
    , containedNodes = Set.empty
    , enclosingNode = Nothing
    }


abLink : D2Link
abLink =
    { fromNode = "a"
    , toNode = "b"
    , label = "from a to b"
    , class = Just linkClass.id
    , attributes = Dict.empty
    }
