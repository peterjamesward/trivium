module DomainModel exposing (..)

import Dict exposing (..)
import Set exposing (..)


type alias NodeId =
    String


type alias AttributeId =
    String


type alias AttributeValue =
    String


type alias ClassId =
    String


type alias DiagramId =
    String


type alias D2Class =
    -- Essentially, we use class attribute for layout and rendering.
    { id : ClassId
    , attributes : Dict String String
    }


type alias D2Node =
    -- Boxes, what can contain other boxes and other non-box stuff.
    { id : NodeId
    , label : String
    , class : Maybe ClassId
    , attributes : Dict String String
    , containedNodes : Set NodeId
    , enclosingNode : Maybe NodeId
    }


type alias D2Link =
    -- Links, what join boxes but also carry their own extra information.
    { fromNode : NodeId -- could be dot-separated hierarchic reference.
    , toNode : NodeId
    , label : String
    , class : Maybe ClassId
    , attributes : Dict String String
    }


type alias D2Diagram =
    -- A diagram is just a collection of the above.
    { id : DiagramId
    , classes : Dict ClassId D2Class
    , nodes : Dict NodeId D2Node
    , links : Dict ( NodeId, NodeId ) D2Link
    }


emptyDiagram : D2Diagram
emptyDiagram =
    D2Diagram "TEST" Dict.empty Dict.empty Dict.empty
