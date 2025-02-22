module DomainModel exposing (..)

import Color exposing (..)
import Dict exposing (..)
import Set exposing (..)


type alias Triple =
    ( String, String, String )


type alias NodeId =
    String


type alias LinkId =
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


type alias ModuleId =
    String


type Shape
    = Cube
    | Cylinder
    | Cone
    | Sphere


type alias Style =
    -- Essentially, we use class attribute for layout and rendering.
    -- Put these here not in Class, so we can rebind them for each dagram.
    { id : StyleId
    , colour : Color
    , shape : Shape
    }


type alias Class =
    { id : ClassId
    , label : Maybe String
    , nodeIds : Set NodeId
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
    { linkId : LinkId -- can't use node pair as may have parallel links.
    , fromNode : NodeId
    , toNode : NodeId
    , label : String
    , class : Maybe ClassId
    , attributes : Dict String String
    }


type alias Module =
    -- A module contains classes, nodes and links.
    { id : ModuleId
    , label : String
    , sourceFile : Maybe String -- if was loaded from disc.
    , classes : Dict ClassId Class
    , nodes : Dict NodeId Node
    , links : Dict LinkId Link
    }


emptyModule : Module
emptyModule =
    { id = ""
    , label = ""
    , sourceFile = Nothing
    , classes = Dict.empty
    , nodes = Dict.empty
    , links = Dict.empty
    }


type alias Diagram =
    -- A diagram contains styles and style bindings.
    -- Not sure if we _derive_ this from a Module, or what...
    { id : DiagramId
    , bindings : Dict ClassId StyleId
    , styles : Dict StyleId Style
    }
