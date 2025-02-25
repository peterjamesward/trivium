module Force3DLayout exposing (..)

import Angle exposing (..)
import Arc3d exposing (..)
import Axis3d exposing (..)
import Block3d
import BoundingBox3d exposing (..)
import Camera3d exposing (..)
import Circle3d exposing (..)
import Color
import Cone3d
import Cylinder3d
import Dict exposing (Dict)
import Direction3d exposing (..)
import DomainModel exposing (..)
import Element exposing (..)
import Frame3d
import Html.Events as HE
import Html.Events.Extra.Mouse as Mouse exposing (Button(..))
import Html.Events.Extra.Wheel as Wheel
import Json.Decode as Decode
import Length exposing (Meters)
import List.Extra
import Maybe.Extra
import Pixels exposing (..)
import Point2d exposing (..)
import Point3d exposing (..)
import Point3d.Projection
import Polyline3d
import Quantity
import Rectangle2d exposing (..)
import Scene3d exposing (..)
import Scene3d.Material as Material
import Set exposing (..)
import SketchPlane3d exposing (..)
import Sphere3d
import Time
import Vector3d exposing (..)
import Viewpoint3d



--TODO: Effective rewrite with cherry picking to avoid inherited debt.
--TODO: Combine with My3dScene.


type WorldCoordinates
    = WorldCoordinates


type DragAction
    = DragNone
    | DragRotate ( Float, Float )
    | DragPan ( Float, Float )


type alias Model =
    { -- Layout.
      repulsion : Float -- relative node repulsion force
    , tension : Float -- relative link pull force
    , fieldStrength : Float -- relative field alignment force for links
    , gravitationalConstant : Float -- avoid infinite expansion
    , timeDelta : Float -- how much to apply force each tick.
    , positions : Dict String (Point3d Meters WorldCoordinates)
    , timeLayoutBegan : Time.Posix
    , lastTick : Time.Posix

    -- Rendering.
    , azimuth : Angle -- Orbiting angle of the camera around the focal point
    , elevation : Angle -- Angle of the camera up from the XY plane
    , scene : List (Entity WorldCoordinates) -- Saved Mesh values for rendering
    , zoomLevel : Float
    , focalPoint : Point3d Meters WorldCoordinates
    , dragging : DragAction
    , screenRectangle : Rectangle2d Pixels WorldCoordinates
    , labelsAndLocations : List ClickIndexEntry -- Mainly for click detection.
    , waitingForClickDelay : Bool
    , biggestBox : BoundingBox3d Meters WorldCoordinates
    }


type Msg
    = AnimationTick Time.Posix
    | SetRepulsion Float
    | SetTension Float
    | SetFieldStrength Float
    | ChangeContent
    | MouseDown Mouse.Event
    | MouseUp Mouse.Event
    | MouseMove Mouse.Event
    | MouseWheel Float
    | NoOp -- for suppressing popup context menu on right click.
    | ContentAreaChanged Int Int
    | UserClick Mouse.Event
    | ClickDelayExpired


init : ( Int, Int ) -> Model
init ( width, height ) =
    { -- Layout.
      repulsion = 1.0
    , tension = 3.0
    , fieldStrength = 0.1
    , gravitationalConstant = 0.05
    , timeDelta = 0.1
    , positions = Dict.empty
    , timeLayoutBegan = Time.millisToPosix 0
    , lastTick = Time.millisToPosix 0

    -- Rendering.
    , azimuth = Angle.degrees 45
    , elevation = Angle.degrees 30
    , scene = []
    , zoomLevel = 0.0
    , focalPoint = Point3d.origin
    , dragging = DragNone
    , screenRectangle =
        Rectangle2d.from
            (Point2d.xy (Pixels.pixels <| Basics.toFloat width) Quantity.zero)
            (Point2d.xy Quantity.zero (Pixels.pixels <| Basics.toFloat height))
    , labelsAndLocations = []
    , waitingForClickDelay = False
    , biggestBox = BoundingBox3d.singleton Point3d.origin
    }


computeInitialPositions :
    Module
    -> Model
    -> Model
computeInitialPositions content model =
    let
        nodeLocations : List (Point3d Meters WorldCoordinates)
        nodeLocations =
            -- Start by distributing nodes arbitrarily (not randomly) around a circle.
            Circle3d.withRadius (Length.meters 100) Direction3d.z Point3d.origin
                |> Circle3d.toArc
                |> Arc3d.segments (Dict.size content.nodes)
                |> Polyline3d.vertices

        nodePositions : Dict NodeId (Point3d Meters WorldCoordinates)
        nodePositions =
            List.Extra.zip (Dict.keys content.nodes) nodeLocations
                |> Dict.fromList

        linkPositions : Dict LinkId (Point3d Meters WorldCoordinates)
        linkPositions =
            -- We use a central point for each link, to allow parallel links
            -- and possibility of curved links later. The reified link id acts
            -- in the dictionary like a virtual node, so the force layout
            -- works seamlessly.
            content.links
                |> Dict.map
                    (\id link ->
                        case
                            ( Dict.get link.fromNode nodePositions
                            , Dict.get link.toNode nodePositions
                            )
                        of
                            ( Just from, Just to ) ->
                                Point3d.midpoint from to

                            _ ->
                                Point3d.origin
                    )

        linksAndNodes =
            -- both string ids really
            Dict.union nodePositions linkPositions

        modelWithInitialPositions =
            { model | positions = linksAndNodes }
    in
    makeMeshFromCurrentPositions content.nodes content.links modelWithInitialPositions


makeMeshFromCurrentPositions :
    Dict NodeId Node
    -> Dict LinkId Link
    -> Model
    -> Model
makeMeshFromCurrentPositions nodes links model =
    let
        nodeMesh =
            --TODO: Put back the forces and animation.
            --TODO: SVG overlay.
            --TODO: Invert 2d points for click lookup. ( point -> Node | Link ).
            nodes
                |> Dict.keys
                |> List.filterMap
                    (\nodeId ->
                        case Dict.get nodeId model.positions of
                            Just position ->
                                Sphere3d.withRadius (Length.meters 8) position
                                    |> Scene3d.sphere (Material.color Color.red)
                                    |> Just

                            Nothing ->
                                Nothing
                    )

        linkMesh =
            -- NOTE: The linkId acts like a virtual node in the positions dict.
            links
                |> Dict.values
                |> List.concatMap
                    (\link ->
                        case
                            ( Dict.get link.fromNode model.positions
                            , Dict.get link.linkId model.positions
                            , Dict.get link.toNode model.positions
                            )
                        of
                            ( Just from, Just mid, Just to ) ->
                                [ Cylinder3d.from from mid (Length.meters 2)
                                , Cylinder3d.from mid to (Length.meters 2)
                                ]
                                    |> List.filterMap identity
                                    |> List.map (Scene3d.cylinder (Material.color Color.blue))

                            _ ->
                                []
                    )
    in
    { model
        | timeLayoutBegan = model.lastTick
        , scene = nodeMesh ++ linkMesh
    }


update :
    Msg
    -> Module
    -> Model
    -> ( Model, Maybe String )
update msg aModule model =
    case msg of
        AnimationTick now ->
            ( { model | lastTick = now }
                |> (if Time.posixToMillis now < Time.posixToMillis model.timeLayoutBegan + 30000 then
                        applyForces aModule.nodes aModule.links

                    else
                        identity
                   )
            , Nothing
            )

        SetRepulsion float ->
            ( model, Nothing )

        SetTension float ->
            ( model, Nothing )

        SetFieldStrength float ->
            ( model, Nothing )

        ChangeContent ->
            ( model, Nothing )

        NoOp ->
            -- Here to allow ignoring right click.
            ( model, Nothing )

        -- Start orbiting when a mouse button is pressed
        MouseDown event ->
            let
                alternate =
                    event.keys.ctrl || event.button == Mouse.SecondButton

                screenPoint =
                    Point2d.fromTuple Pixels.pixels event.offsetPos

                dragging =
                    if alternate then
                        DragRotate event.offsetPos

                    else
                        DragPan event.offsetPos
            in
            ( { model
                | dragging = dragging
                , waitingForClickDelay = True
              }
            , Nothing
            )

        -- Stop orbiting when a mouse button is released
        MouseUp event ->
            ( { model
                | dragging = DragNone
                , waitingForClickDelay = False
              }
            , Nothing
            )

        ClickDelayExpired ->
            ( { model | waitingForClickDelay = False }
            , Nothing
            )

        -- Orbit camera on mouse move (if a mouse button is down)
        MouseMove event ->
            let
                ( newx, newy ) =
                    event.offsetPos
            in
            case model.dragging of
                DragRotate lastMouseLocation ->
                    let
                        ( dx, dy ) =
                            ( Pixels.pixels <| newx - Tuple.first lastMouseLocation
                            , Pixels.pixels <| newy - Tuple.second lastMouseLocation
                            )

                        rotationRate =
                            Angle.degrees 1 |> Quantity.per Pixels.pixel

                        newAzimuth =
                            model.azimuth
                                |> Quantity.minus (Quantity.at rotationRate dx)

                        newElevation =
                            model.elevation
                                |> Quantity.plus (Quantity.at rotationRate dy)
                                |> Quantity.clamp (Angle.degrees -90) (Angle.degrees 90)
                    in
                    ( { model
                        | azimuth = newAzimuth
                        , elevation = newElevation
                        , dragging = DragRotate event.offsetPos

                        -- , labelsAndLocations = projectOntoScreen model model.labelsAndLocations
                      }
                    , Nothing
                    )

                DragPan ( startX, startY ) ->
                    let
                        viewpoint =
                            Viewpoint3d.orbitZ
                                { focalPoint = model.focalPoint
                                , azimuth = model.azimuth
                                , elevation = model.elevation
                                , distance = Length.meters <| 1000 * 2 ^ model.zoomLevel
                                }

                        camera =
                            Camera3d.perspective
                                { verticalFieldOfView = Angle.degrees 50
                                , viewpoint = viewpoint
                                }

                        viewPlane =
                            SketchPlane3d.withNormalDirection
                                (Viewpoint3d.viewDirection <| Camera3d.viewpoint camera)
                                model.focalPoint

                        grabPointOnScreen =
                            Point2d.pixels startX startY

                        movePointOnScreen =
                            Point2d.fromTuple Pixels.pixels event.offsetPos

                        grabPointInModel =
                            Camera3d.ray camera model.screenRectangle grabPointOnScreen
                                |> Axis3d.intersectionWithPlane (SketchPlane3d.toPlane viewPlane)

                        movePointInModel =
                            Camera3d.ray camera model.screenRectangle movePointOnScreen
                                |> Axis3d.intersectionWithPlane (SketchPlane3d.toPlane viewPlane)
                    in
                    case ( grabPointInModel, movePointInModel ) of
                        ( Just pick, Just drop ) ->
                            let
                                shift =
                                    Vector3d.from pick drop
                                        |> Vector3d.projectInto viewPlane

                                newFocus =
                                    Point2d.origin
                                        |> Point2d.translateBy shift
                                        |> Point3d.on viewPlane
                            in
                            ( { model
                                | focalPoint = newFocus
                                , dragging = DragPan event.offsetPos

                                -- , labelsAndLocations = projectOntoScreen model model.labelsAndLocations
                              }
                            , Nothing
                            )

                        _ ->
                            ( model, Nothing )

                _ ->
                    ( model, Nothing )

        MouseWheel delta ->
            let
                increment =
                    0.01 * delta
            in
            ( { model
                | zoomLevel = clamp -10 10 <| model.zoomLevel + increment

                -- , labelsAndLocations = projectOntoScreen model model.labelsAndLocations
              }
            , Nothing
            )

        ContentAreaChanged width height ->
            ( { model
                | screenRectangle =
                    Rectangle2d.from
                        (Point2d.xy (Pixels.pixels <| Basics.toFloat width) Quantity.zero)
                        (Point2d.xy Quantity.zero (Pixels.pixels <| Basics.toFloat height))

                -- , labelsAndLocations = projectOntoScreen model model.labelsAndLocations
              }
            , Nothing
            )

        UserClick event ->
            -- Just <| findNearestLabel event.offsetPos model.labelsAndLocations )
            ( model, Nothing )


type alias ClickIndexEntry =
    -- Handy form for rendering and click detection.
    { nodeId : NodeId
    , label : String
    , isLink : Bool
    , location : Point3d Meters WorldCoordinates
    , linkWaypoints : List (Point3d Meters WorldCoordinates)
    , screenLocation : Maybe (Point2d Pixels WorldCoordinates) -- set by My3dscene only for visible points.
    , screenLocationForSVG : Maybe (Point2d Pixels WorldCoordinates) -- probably redundant.
    , colour : String
    , shape : String
    }


makeShape :
    ClickIndexEntry
    -> Entity WorldCoordinates
makeShape entry =
    let
        material =
            Color.grey
                |> Material.color
    in
    case entry.shape of
        "sphere" ->
            Sphere3d.withRadius (Length.meters 8) entry.location
                |> Scene3d.sphere material

        "cube" ->
            Block3d.centeredOn (Frame3d.atPoint entry.location)
                ( Length.meters 12, Length.meters 12, Length.meters 12 )
                |> Scene3d.block material

        "cone" ->
            Cone3d.startingAt entry.location
                Direction3d.positiveZ
                { radius = Length.meters 8, length = Length.meters 12 }
                |> Scene3d.cone material

        "cylinder" ->
            Cylinder3d.startingAt entry.location
                Direction3d.positiveZ
                { radius = Length.meters 8, length = Length.meters 8 }
                |> Scene3d.cylinder material

        _ ->
            Sphere3d.withRadius (Length.meters 8) entry.location
                |> Scene3d.sphere material


onContextMenu : a -> Element.Attribute a
onContextMenu msg =
    HE.custom "contextmenu"
        (Decode.succeed
            { message = msg
            , stopPropagation = True
            , preventDefault = True
            }
        )
        |> htmlAttribute


view :
    (Msg -> msg)
    -> Model
    -> Element msg
view wrapper model =
    let
        -- Create a camera by orbiting around a Z axis through the given
        -- focal point, with azimuth measured from the positive X direction
        -- towards positive Y
        viewpoint =
            Viewpoint3d.orbitZ
                { focalPoint = model.focalPoint
                , azimuth = model.azimuth
                , elevation = model.elevation
                , distance = Length.meters <| 1000 * 2 ^ model.zoomLevel
                }

        camera =
            Camera3d.perspective
                { verticalFieldOfView = Angle.degrees 50
                , viewpoint = viewpoint
                }

        ( w, h ) =
            Rectangle2d.dimensions model.screenRectangle
    in
    Element.el
        [ htmlAttribute <| Mouse.onDown (wrapper << MouseDown)
        , htmlAttribute <| Mouse.onMove (wrapper << MouseMove)
        , htmlAttribute <| Mouse.onUp (wrapper << MouseUp)
        , htmlAttribute <| Wheel.onWheel (wrapper << MouseWheel << .deltaY)
        , Element.width fill
        , Element.height fill
        , htmlAttribute <| Mouse.onClick (UserClick >> wrapper)

        --, htmlAttribute <| Mouse.onDoubleClick (ImageDoubleClick >> msgWrapper)
        -- , inFront <| textOverlay model.screenRectangle camera model
        , onContextMenu (wrapper NoOp)
        ]
    <|
        Element.html <|
            Scene3d.sunny
                { camera = camera
                , clipDepth = Length.meters 0.1
                , dimensions = ( Quantity.round w, Quantity.round h )
                , background = Scene3d.backgroundColor Color.lightGrey
                , entities = model.scene
                , shadows = True
                , sunlightDirection = Direction3d.xyZ (Angle.degrees 45) (Angle.degrees 70)
                , upDirection = Direction3d.positiveZ
                }


subscriptions : (Msg -> msg) -> Model -> Sub msg
subscriptions msgWrapper model =
    if Time.posixToMillis model.lastTick < Time.posixToMillis model.timeLayoutBegan + 30000 then
        Time.every 100 (msgWrapper << AnimationTick)

    else
        Sub.none


applyForces :
    Dict NodeId Node
    -> Dict LinkId Link
    -> Model
    -> Model
applyForces nodes links model =
    -- Finally, this is what we are here for.
    -- I know this is quadratic. I also know that can optimise with a strict falloff
    -- using (say) octree, or using a statistical approximation.
    let
        withGravitationalConstant : Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
        withGravitationalConstant =
            -- Avoid clusters spinning off.
            model.positions
                |> Dict.map
                    (\thisNode position ->
                        ( position
                        , Vector3d.from position Point3d.origin
                            |> Vector3d.multiplyBy model.gravitationalConstant
                        )
                    )

        withRepulsion : Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
        withRepulsion =
            withGravitationalConstant
                |> Dict.map
                    (\thisNode ( position, before ) ->
                        let
                            netForce =
                                Dict.foldl
                                    (\otherNode otherPosition total ->
                                        let
                                            force =
                                                Length.meters 60
                                                    |> Quantity.minus (Point3d.distanceFrom position otherPosition)
                                                    |> Quantity.clamp Quantity.zero (Length.meters 60)
                                                    |> Quantity.negate

                                            forceVector =
                                                Vector3d.from position otherPosition
                                                    |> Vector3d.scaleTo force
                                        in
                                        if thisNode /= otherNode then
                                            total |> Vector3d.plus forceVector

                                        else
                                            total
                                    )
                                    Vector3d.zero
                                    model.positions
                        in
                        ( position
                        , Vector3d.plus before
                            (netForce |> Vector3d.multiplyBy model.repulsion)
                        )
                    )

        withAttraction : Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
        withAttraction =
            -- links
            --     |> Dict.foldl
            --         (\linkId reifiedLink forcesDict ->
            --             let
            --                 ( s, o ) =
            --                     ( reifiedLink.subject, reifiedLink.object )
            --             in
            --             case ( Dict.get s forcesDict, Dict.get o forcesDict ) of
            --                 ( Just ( sPos, sForce ), Just ( oPos, oForce ) ) ->
            --                     let
            --                         attraction =
            --                             Point3d.distanceFrom sPos oPos
            --                                 |> Quantity.minus (Length.meters 30)
            --                                 |> Quantity.max Quantity.zero
            --                         forceOnS =
            --                             Vector3d.from sPos oPos
            --                                 |> Vector3d.scaleTo attraction
            --                         forceOnO =
            --                             Vector3d.from oPos sPos
            --                                 |> Vector3d.scaleTo attraction
            --                     in
            --                     forcesDict
            --                         |> Dict.insert s ( sPos, Vector3d.plus sForce forceOnS )
            --                         |> Dict.insert o ( oPos, Vector3d.plus oForce forceOnO )
            --                 _ ->
            --                     forcesDict
            --         )
            withRepulsion

        withFields : Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
        withFields =
            withAttraction

        {-
           Look for links with "direction".
           These should be reified links, so easy to spot.
             _3029807074 FROM peter.
             _3029807074 LABEL tallerThan.
             _3029807074 TO sharon.
             _3029807074 TYPE personal.
             personal direction UP.
        -}
        -- links
        -- |> Dict.foldl addRotationalForcesIfLinkHasDirection withAttraction
        -- addRotationalForcesIfLinkHasDirection :
        --     LinkId
        --     -> Link
        --     -> Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
        --     -> Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
        -- addRotationalForcesIfLinkHasDirection linkId reified collector =
        --     -- Should cater for reified links but also simple links where the label is the type.
        --     -- (which should be covered by the nodesTypes.)
        --     case
        --         ( Dict.get reified.fromNode collector
        --         , Dict.get reified.toNode collector
        --         )
        --     of
        --         ( Just ( sPos, sForce ), Just ( oPos, oForce ) ) ->
        --             case Dict.get (String.toUpper reified.direction) directionVectors of
        --                 Just desiredDirection ->
        --                     -- Note that these forces apply to the "actual" subject and object.
        --                     let
        --                         currentVector =
        --                             Vector3d.from sPos oPos
        --                         desiredVector =
        --                             Vector3d.withLength
        --                                 (Vector3d.length currentVector)
        --                                 desiredDirection
        --                         correctiveForceAtStart =
        --                             desiredVector
        --                                 |> Vector3d.minus currentVector
        --                                 |> Vector3d.multiplyBy model.fieldStrength
        --                         correctiveForceAEnd =
        --                             Vector3d.reverse correctiveForceAtStart
        --                                 |> Vector3d.multiplyBy model.fieldStrength
        --                     in
        --                     collector
        --                         |> Dict.insert reified.subject ( sPos, Vector3d.plus sForce correctiveForceAtStart )
        --                         |> Dict.insert reified.object ( oPos, Vector3d.plus oForce correctiveForceAEnd )
        --                 _ ->
        --                     collector
        --         _ ->
        --             collector
        newPositions : Dict String (Point3d Meters WorldCoordinates)
        newPositions =
            withFields
                |> Dict.map
                    (\thisNode ( position, force ) ->
                        position
                            |> Point3d.translateBy (Vector3d.scaleBy model.timeDelta force)
                    )

        modelWithNewPositions =
            { model | positions = newPositions }
    in
    makeMeshFromCurrentPositions nodes links modelWithNewPositions
