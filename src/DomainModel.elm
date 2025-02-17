module DomainModel exposing (..)

import Color exposing (..)
import Dict exposing (..)
import Set exposing (..)


type alias NodeId =
    String


type alias AttributeId =
    String


type alias AttributeValue =
    String


type alias StyleId =
    String


type alias ClassId =
    String


type alias DiagramId =
    String


type Shape
    = Cube
    | Cylinder
    | Cone
    | Sphere


type alias Style =
    -- Essentially, we use class attribute for layout and rendering.
    { id : StyleId
    , colour : Color
    , shape : Shape
    }


type alias StyleBinding =
    Dict ClassId StyleId


type alias Class =
    { id : ClassId
    , label : String
    }


type alias Node =
    -- Boxes, what can contain other boxes and other non-box stuff.
    { id : NodeId
    , label : String
    , class : Maybe ClassId
    , attributes : Dict String String
    }


type alias Link =
    -- Links, join boxes and carry their own information.
    { fromNode : NodeId
    , toNode : NodeId
    , label : String
    , class : Maybe ClassId
    , attributes : Dict String String
    }


type alias Diagram =
    -- A diagram is just a collection of the above.
    { id : DiagramId
    , classes : Dict ClassId Class
    , nodes : Dict NodeId Node
    , links : Dict ( NodeId, NodeId ) Link
    }


emptyDiagram : Diagram
emptyDiagram =
    Diagram "TEST" Dict.empty Dict.empty Dict.empty
