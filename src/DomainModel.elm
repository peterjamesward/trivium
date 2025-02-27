module DomainModel exposing (..)

import Color exposing (..)
import Dict exposing (..)
import Direction3d exposing (..)
import Set exposing (..)


type WorldCoordinates
    = WorldCoordinates


type SVGCoordinates
    = SVGCoordinates


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


type alias InnerDict =
    Dict String (Set String)


type alias OuterDict =
    Dict String InnerDict


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
    , attributes : InnerDict
    }


type alias Node =
    -- Boxes, what can contain other boxes and other non-box stuff.
    -- Note that attributes will not show as links on the visuals, only in the inspector.
    -- This forces the user to declare explicit links.
    { id : NodeId
    , label : Maybe String
    , class : Maybe ClassId
    , attributes : InnerDict
    }


type alias Link =
    -- Links, join boxes and carry their own information.
    { linkId : LinkId -- can't use node pair as may have parallel links.
    , fromNode : NodeId
    , toNode : NodeId
    , label : String
    , class : Maybe ClassId
    , attributes : InnerDict
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


preferredLinkDirection : Module -> Link -> Maybe (Direction3d WorldCoordinates)
preferredLinkDirection content link =
    case link.class of
        Just class ->
            case Dict.get class content.classes of
                Just theClass ->
                    case Dict.get "direction" theClass.attributes of
                        Just directions ->
                            let
                                direction =
                                    directions
                                        |> Set.toList
                                        |> List.head
                                        |> Maybe.withDefault "none"
                            in
                            Dict.get (String.toLower direction) <|
                                Dict.fromList
                                    [ ( "north", Direction3d.positiveY )
                                    , ( "south", Direction3d.negativeY )
                                    , ( "east", Direction3d.positiveX )
                                    , ( "west", Direction3d.negativeX )
                                    , ( "up", Direction3d.positiveZ )
                                    , ( "down", Direction3d.negativeZ )
                                    ]

                        Nothing ->
                            Nothing

                Nothing ->
                    Nothing

        Nothing ->
            Nothing
