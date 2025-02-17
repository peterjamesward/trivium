module TestDiagram exposing (testDiagram)

import Dict exposing (..)
import DomainModel exposing (..)


testDiagram : Diagram
testDiagram =
    { id = "TEST"
    , classes = testClasses
    , nodes = testNodes
    , links = testLinks
    }


fruitClass : Class
fruitClass =
    { id = "Fruit"
    , label = "fruity and healthy"
    }


vegClass : Class
vegClass =
    { id = "Vegetable"
    , label = "healthy but not fruity"
    }


testClasses : Dict ClassId Class
testClasses =
    Dict.fromList
        [ ( fruitClass.id, fruitClass )
        , ( vegClass.id, vegClass )
        ]


apple : Node
apple =
    { id = "apple"
    , label = "keeps the dentist away"
    , class = Just fruitClass.id
    , attributes = Dict.empty
    }


carrot =
    { id = "carrot"
    , label = "see better at night"
    , class = Just vegClass.id
    , attributes = Dict.empty
    }


testNodes =
    Dict.fromList
        [ ( apple.id, apple )
        , ( carrot.id, carrot )
        ]


isnt =
    { fromNode = carrot.id
    , toNode = apple.id
    , label = "not to be confused with"
    , class = Nothing
    , attributes = Dict.empty
    }


testLinks =
    Dict.singleton
        ( isnt.fromNode, isnt.toNode )
        isnt
