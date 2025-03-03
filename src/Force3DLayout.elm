module Force3DLayout exposing (..)

import Angle exposing (..)
import Arc3d exposing (..)
import Axis2d exposing (..)
import Axis3d exposing (..)
import Block3d
import BoundingBox3d exposing (..)
import Camera3d exposing (..)
import Circle3d exposing (..)
import Color
import CommonUiElements exposing (..)
import Cone3d
import Cylinder3d
import Dict exposing (Dict)
import Direction2d exposing (..)
import Direction3d exposing (..)
import DomainModel exposing (..)
import Element exposing (..)
import Element.Input as Input
import Frame2d
import Frame3d
import Geometry.Svg as Svg
import Html.Events as HE
import Html.Events.Extra.Mouse as Mouse exposing (Button(..))
import Html.Events.Extra.Wheel as Wheel
import Json.Decode as Decode
import Length exposing (Meters)
import List.Extra
import Maybe.Extra
import Pixels exposing (..)
import Plane3d exposing (..)
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
import Svg
import Svg.Attributes
import Time
import Vector3d exposing (..)
import Viewpoint3d


type alias Position3d =
    Point3d Meters WorldCoordinates


type alias PositionSVG =
    Point2d Pixels SVGCoordinates


type DragAction
    = DragNone
    | DragRotate ( Float, Float )
    | DragPan ( Float, Float )


type alias Position =
    { -- Use one structure for all our internal purposes.
      position3d : Position3d
    , positionSvg : PositionSVG
    , label : String
    , force : Vector3d Meters WorldCoordinates
    }


type alias Model =
    { -- Layout.
      repulsion : Float -- relative node repulsion force
    , tension : Float -- relative link pull force
    , fieldStrength : Float -- relative field alignment force for links
    , gravitationalConstant : Float -- avoid infinite expansion
    , timeDelta : Float -- how much to apply force each tick.
    , positions : Dict String Position
    , timeLayoutBegan : Time.Posix
    , lastTick : Time.Posix
    , animation : Bool

    -- Rendering.
    , azimuth : Angle -- Orbiting angle of the camera around the focal point
    , elevation : Angle -- Angle of the camera up from the XY plane
    , scene : List (Entity WorldCoordinates) -- Saved Mesh values for rendering
    , zoomLevel : Float
    , focalPoint : Point3d Meters WorldCoordinates
    , dragging : DragAction
    , screenRectangle : Rectangle2d Pixels SVGCoordinates
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
    | UserClicksPlay
    | UserClicksPause


init : ( Int, Int ) -> Model
init ( width, height ) =
    { -- Layout.
      repulsion = 1.0
    , tension = 1.0
    , fieldStrength = 0.2
    , gravitationalConstant = 0.01
    , timeDelta = 0.1
    , positions = Dict.empty
    , timeLayoutBegan = Time.millisToPosix 0
    , lastTick = Time.millisToPosix 0
    , animation = False

    -- Rendering.
    , azimuth = Angle.degrees 0
    , elevation = Angle.degrees 90
    , scene = []
    , zoomLevel = 0.0
    , focalPoint = Point3d.origin
    , dragging = DragNone
    , screenRectangle =
        Rectangle2d.from
            (Point2d.xy (Pixels.pixels <| Basics.toFloat width) Quantity.zero)
            (Point2d.xy Quantity.zero (Pixels.pixels <| Basics.toFloat height))
    , waitingForClickDelay = False
    , biggestBox = BoundingBox3d.singleton Point3d.origin
    }


computeInitialPositions :
    Module
    -> Model
    -> Model
computeInitialPositions content model =
    -- Must make sure that parallel links are separated at the start, so the repulsion works.
    -- Do this by treating the virtual nodes (link midpoints) the same as real nodes.
    let
        -- Experimentally, preserve positions from prior state.
        -- Use default positions only for new nodes and links.
        pointWrap pt label =
            { position3d = pt
            , positionSvg = Point2d.origin
            , label = label
            , force = Vector3d.zero
            }

        nodeCircle : List (Point3d Meters WorldCoordinates)
        nodeCircle =
            -- Start by distributing nodes arbitrarily (not randomly) around a circle.
            Circle3d.withRadius (Length.meters 100) Direction3d.z Point3d.origin
                |> Circle3d.toArc
                |> Arc3d.segments (Dict.size content.nodes + Dict.size content.links)
                |> Polyline3d.vertices

        nodePositions : Dict NodeId Position
        nodePositions =
            content.nodes
                |> Dict.map (\id node -> ( id, Maybe.withDefault id node.label ))
                |> Dict.values
                |> List.Extra.zip (List.take (Dict.size content.nodes) nodeCircle)
                |> List.map
                    (\( pos, ( id, label ) ) -> ( id, pointWrap pos label ))
                |> Dict.fromList

        linkPositions : Dict LinkId Position
        linkPositions =
            content.links
                |> Dict.map (\id link -> ( id, link.label ))
                |> Dict.values
                |> List.Extra.zip (List.drop (Dict.size content.nodes) nodeCircle)
                |> List.map
                    (\( pos, ( id, label ) ) -> ( id, pointWrap pos label ))
                |> Dict.fromList

        linksAndNodes =
            -- both string ids really
            Dict.union nodePositions linkPositions

        mergeNewAndOldPositions =
            -- Will be amazing if this is all it takes!
            Dict.intersect (Dict.union model.positions linksAndNodes) linksAndNodes

        modelWithInitialPositions =
            { model | positions = mapToSvg model mergeNewAndOldPositions }
    in
    makeMeshFromCurrentPositions content modelWithInitialPositions


makeMeshFromCurrentPositions :
    Module
    -> Model
    -> Model
makeMeshFromCurrentPositions aModule model =
    let
        nodeMesh =
            --TODO: Styling.
            aModule.nodes
                |> Dict.map
                    (\nodeId node ->
                        let
                            style =
                                -- Debug.log "STYLE" <|
                                DomainModel.nodeStyle aModule node
                        in
                        case Dict.get nodeId model.positions of
                            Just position ->
                                case style.shape of
                                    Cube ->
                                        Block3d.centeredOn
                                            (Frame3d.atPoint position.position3d)
                                            ( Length.meters 9
                                            , Length.meters 9
                                            , Length.meters 9
                                            )
                                            |> Scene3d.block (Material.color style.colour)
                                            |> Just

                                    Cylinder ->
                                        Cylinder3d.centeredOn
                                            (Point3d.translateIn Direction3d.negativeZ (Length.meters 4) position.position3d)
                                            Direction3d.positiveZ
                                            { radius = Length.meters 5, length = Length.meters 12 }
                                            |> Scene3d.cylinder (Material.color style.colour)
                                            |> Just

                                    Cone ->
                                        Cone3d.startingAt
                                            position.position3d
                                            Direction3d.positiveZ
                                            { radius = Length.meters 5, length = Length.meters 12 }
                                            |> Scene3d.cone (Material.color style.colour)
                                            |> Just

                                    _ ->
                                        Sphere3d.withRadius (Length.meters 5) position.position3d
                                            |> Scene3d.sphere (Material.color style.colour)
                                            |> Just

                            Nothing ->
                                Nothing
                    )
                |> Dict.values
                |> List.filterMap identity

        linkMesh =
            -- NOTE: The linkId acts like a virtual node in the positions dict.
            --TODO: Styling.
            aModule.links
                |> Dict.values
                |> List.concatMap
                    (\link ->
                        let
                            style =
                                -- Debug.log "STYLE" <|
                                DomainModel.linkStyle aModule link
                        in
                        case
                            ( Dict.get link.fromNode model.positions
                            , Dict.get link.linkId model.positions
                            , Dict.get link.toNode model.positions
                            )
                        of
                            ( Just from, Just mid, Just to ) ->
                                let
                                    direction =
                                        Direction3d.from from.position3d to.position3d
                                            |> Maybe.withDefault Direction3d.positiveZ

                                    cone =
                                        Cone3d.startingAt
                                            mid.position3d
                                            direction
                                            { radius = Length.meters 2
                                            , length = Length.meters 10
                                            }

                                    shiftedCone =
                                        cone |> Cone3d.translateIn direction (Length.meters -5)
                                in
                                Scene3d.cone (Material.color style.colour) shiftedCone
                                    :: ([ Cylinder3d.from from.position3d mid.position3d (Length.meters 1)
                                        , Cylinder3d.from mid.position3d to.position3d (Length.meters 1)
                                        ]
                                            |> List.filterMap identity
                                            |> List.map (Scene3d.cylinder (Material.color style.colour))
                                       )

                            _ ->
                                []
                    )
    in
    { model | scene = nodeMesh ++ linkMesh }


update :
    Msg
    -> Module
    -> Model
    -> ( Model, Maybe String )
update msg aModule model =
    case msg of
        UserClicksPlay ->
            ( { model | animation = True }, Nothing )

        UserClicksPause ->
            ( { model | animation = False }, Nothing )

        AnimationTick now ->
            ( { model | lastTick = now } |> applyForces aModule
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
                DragRotate ( lastX, lastY ) ->
                    let
                        ( dx, dy ) =
                            ( Pixels.pixels <| newx - lastX
                            , Pixels.pixels <| newy - lastY
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

                        modelWithNewView =
                            { model
                                | azimuth = newAzimuth
                                , elevation = newElevation
                                , dragging = DragRotate event.offsetPos
                            }
                    in
                    ( { modelWithNewView | positions = mapToSvg modelWithNewView modelWithNewView.positions }
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

                                modelWithNewView =
                                    { model
                                        | focalPoint = newFocus
                                        , dragging = DragPan event.offsetPos
                                    }
                            in
                            ( { modelWithNewView | positions = mapToSvg modelWithNewView modelWithNewView.positions }
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

                modelWithNewView =
                    { model | zoomLevel = clamp -10 10 <| model.zoomLevel + increment }
            in
            ( { modelWithNewView | positions = mapToSvg modelWithNewView modelWithNewView.positions }
            , Nothing
            )

        ContentAreaChanged width height ->
            let
                modelWithNewView =
                    { model
                        | screenRectangle =
                            Rectangle2d.from
                                (Point2d.xy (Pixels.pixels <| Basics.toFloat width) Quantity.zero)
                                (Point2d.xy Quantity.zero (Pixels.pixels <| Basics.toFloat height))
                    }
            in
            ( { modelWithNewView | positions = mapToSvg modelWithNewView modelWithNewView.positions }
            , Nothing
            )

        UserClick event ->
            -- Just <| findNearestLabel event.offsetPos model.labelsAndLocations )
            ( model, Nothing )


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
    column CommonUiElements.columnStyles
        [ row neatRowStyles
            [ if model.animation then
                Input.button CommonUiElements.buttonStyles
                    { label = text "Pause"
                    , onPress = Just (wrapper UserClicksPause)
                    }

              else
                Input.button CommonUiElements.buttonStyles
                    { label = text "Play"
                    , onPress = Just (wrapper UserClicksPlay)
                    }
            ]
        , Element.el
            [ htmlAttribute <| Mouse.onDown (wrapper << MouseDown)
            , htmlAttribute <| Mouse.onMove (wrapper << MouseMove)
            , htmlAttribute <| Mouse.onUp (wrapper << MouseUp)
            , htmlAttribute <| Wheel.onWheel (wrapper << MouseWheel << .deltaY)
            , Element.width fill
            , Element.height fill
            , htmlAttribute <| Mouse.onClick (UserClick >> wrapper)

            --, htmlAttribute <| Mouse.onDoubleClick (ImageDoubleClick >> msgWrapper)
            , inFront <| textOverlay model
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
        ]


subscriptions : (Msg -> msg) -> Model -> Sub msg
subscriptions msgWrapper model =
    -- if Time.posixToMillis model.lastTick < Time.posixToMillis model.timeLayoutBegan + 30000 then
    --     Time.every 100 (msgWrapper << AnimationTick)
    -- else
    if model.animation then
        Time.every 100 (msgWrapper << AnimationTick)

    else
        Sub.none


applyForces :
    Module
    -> Model
    -> Model
applyForces theModule model =
    -- Finally, this is what we are here for.
    -- I know this is quadratic. I also know that can optimise with a strict falloff
    -- using (say) octree, or using a statistical approximation.
    let
        links =
            theModule.links

        nodes =
            theModule.nodes

        withGravitationalConstant : Dict String Position
        withGravitationalConstant =
            -- Avoid clusters spinning off.
            model.positions
                |> Dict.map
                    (\thisNode position ->
                        { position
                            | force =
                                Vector3d.from position.position3d Point3d.origin
                                    |> Vector3d.multiplyBy model.gravitationalConstant
                        }
                    )

        withRepulsion : Dict String Position
        withRepulsion =
            withGravitationalConstant
                |> Dict.map
                    (\thisNode position ->
                        let
                            netForce =
                                Dict.foldl
                                    (\otherNode otherPosition total ->
                                        if thisNode /= otherNode then
                                            let
                                                force =
                                                    Length.meters 60
                                                        |> Quantity.minus
                                                            (Point3d.distanceFrom
                                                                position.position3d
                                                                otherPosition.position3d
                                                            )
                                                        |> Quantity.clamp Quantity.zero (Length.meters 60)
                                                        |> Quantity.negate

                                                forceVector =
                                                    Vector3d.from position.position3d otherPosition.position3d
                                                        |> Vector3d.scaleTo force
                                            in
                                            total |> Vector3d.plus forceVector

                                        else
                                            total
                                    )
                                    Vector3d.zero
                                    model.positions
                        in
                        { position
                            | force =
                                Vector3d.plus position.force
                                    (netForce |> Vector3d.multiplyBy model.repulsion)
                        }
                    )

        withAttraction : Dict String Position
        withAttraction =
            -- Each endpoint moves towards the waypoint, the waypoint moves towards the midpoint.
            links
                |> Dict.foldl
                    (\linkId reifiedLink forcesDict ->
                        let
                            ( s, way, o ) =
                                ( reifiedLink.fromNode
                                , reifiedLink.linkId
                                , reifiedLink.toNode
                                )
                        in
                        case
                            ( Dict.get s forcesDict
                            , Dict.get way forcesDict
                            , Dict.get o forcesDict
                            )
                        of
                            ( Just subject, Just waypoint, Just object ) ->
                                let
                                    attractionSW =
                                        -- subject to waypoint
                                        Point3d.distanceFrom subject.position3d waypoint.position3d
                                            |> Quantity.minus (Length.meters 30)
                                            |> Quantity.max Quantity.zero

                                    attractionOW =
                                        -- object to waypoint
                                        Point3d.distanceFrom object.position3d waypoint.position3d
                                            |> Quantity.minus (Length.meters 30)
                                            |> Quantity.max Quantity.zero

                                    midpoint =
                                        Point3d.midpoint subject.position3d object.position3d

                                    waypointDistance =
                                        Point3d.distanceFrom waypoint.position3d midpoint

                                    forceOnS =
                                        Vector3d.from subject.position3d waypoint.position3d
                                            |> Vector3d.scaleTo attractionSW

                                    forceOnO =
                                        Vector3d.from object.position3d waypoint.position3d
                                            |> Vector3d.scaleTo attractionOW

                                    forceOnWaypoint =
                                        Vector3d.from waypoint.position3d midpoint
                                            |> Vector3d.scaleTo waypointDistance
                                in
                                forcesDict
                                    |> Dict.insert s { subject | force = Vector3d.plus subject.force forceOnS }
                                    |> Dict.insert o { object | force = Vector3d.plus object.force forceOnO }
                                    |> Dict.insert way { waypoint | force = Vector3d.plus waypoint.force forceOnWaypoint }

                            _ ->
                                forcesDict
                    )
                    withRepulsion

        withFields : Dict String Position
        withFields =
            {-
               Look for links with "direction".
               These should be reified links, so easy to spot.
                 _3029807074 FROM peter.
                 _3029807074 LABEL tallerThan.
                 _3029807074 TO sharon.
                 _3029807074 TYPE personal.
                 personal direction UP.
            -}
            links
                |> Dict.foldl addRotationalForcesIfLinkHasDirection withAttraction

        addRotationalForcesIfLinkHasDirection :
            LinkId
            -> Link
            -> Dict String Position
            -> Dict String Position
        addRotationalForcesIfLinkHasDirection linkId reified collector =
            -- If we can infer a preferred direction based on link type, try to align the endpoints.
            case
                ( Dict.get reified.fromNode collector
                , Dict.get reified.toNode collector
                )
            of
                ( Just subject, Just object ) ->
                    case preferredLinkDirection theModule reified of
                        Just desiredDirection ->
                            -- Note that these forces apply to the "actual" subject and object.
                            -- If the actual and desired direction define a plane, we will
                            -- try to move the endpoints within that plane perpendicular
                            -- to their current direction. This is more effective than moving
                            -- directly towards the optimal.
                            -- If the directions align so there is
                            -- no plane, any orthogonal direction will do. We will multiply
                            -- the force by the angle between directions, becoming zero if
                            -- they align, so we don't test for that case.
                            let
                                endIfAligned =
                                    -- WHere's the ideal endpoint? Need this to define a plane.
                                    Point3d.translateIn desiredDirection Length.meter subject.position3d

                                currentVector =
                                    Vector3d.from subject.position3d object.position3d

                                correctiveForceAtStart : Vector3d Meters WorldCoordinates
                                correctiveForceAtStart =
                                    case
                                        ( Plane3d.throughPoints subject.position3d object.position3d endIfAligned
                                        , Vector3d.direction currentVector
                                        )
                                    of
                                        ( Just commonPlane, Just currentDirection ) ->
                                            -- We can now find the normal
                                            let
                                                planeNormalAxis =
                                                    Plane3d.normalAxis commonPlane

                                                rotation =
                                                    Direction3d.angleFrom currentDirection desiredDirection
                                            in
                                            currentVector
                                                |> Vector3d.rotateAround planeNormalAxis (Angle.degrees 90)
                                                |> Vector3d.scaleTo (Length.meters <| Angle.inTurns rotation)
                                                |> Vector3d.multiplyBy model.fieldStrength

                                        _ ->
                                            currentVector
                                                |> Vector3d.perpendicularTo
                                                |> Vector3d.scaleTo Length.meter
                                                |> Vector3d.multiplyBy model.fieldStrength

                                correctiveForceAEnd =
                                    Vector3d.reverse correctiveForceAtStart
                            in
                            collector
                                |> Dict.insert reified.fromNode
                                    { subject | force = Vector3d.plus subject.force correctiveForceAtStart }
                                |> Dict.insert reified.toNode
                                    { object | force = Vector3d.plus object.force correctiveForceAEnd }

                        _ ->
                            collector

                _ ->
                    collector

        newPositions : Dict String Position
        newPositions =
            withFields
                |> Dict.map
                    (\thisNode position ->
                        { position
                            | position3d =
                                position.position3d
                                    |> Point3d.translateBy (Vector3d.scaleBy model.timeDelta position.force)
                            , force = Vector3d.zero
                        }
                    )

        modelWithNewPositions =
            { model | positions = mapToSvg model newPositions }
    in
    makeMeshFromCurrentPositions theModule modelWithNewPositions


mapToSvg :
    Model
    -> Dict NodeId Position
    -> Dict NodeId Position
mapToSvg model coords3d =
    -- Takes 3d points and works out the SVG for each.
    let
        ( wPixels, hPixels ) =
            Rectangle2d.dimensions model.screenRectangle

        ( svgWidth, svgHeight ) =
            ( String.fromInt <| round <| Pixels.inPixels wPixels
            , String.fromInt <| round <| Pixels.inPixels hPixels
            )

        useThisRectangleForSVG =
            -- Whatever.
            Rectangle2d.from
                Point2d.origin
                (Point2d.xy wPixels hPixels)

        useThisRectangleForWebGL =
            -- Whatever.
            Rectangle2d.from
                (Point2d.xy Quantity.zero hPixels)
                (Point2d.xy wPixels Quantity.zero)

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

        newEntry : NodeId -> Position -> Position
        newEntry id has3d =
            { has3d
                | positionSvg =
                    Point3d.Projection.toScreenSpace
                        camera
                        useThisRectangleForSVG
                        has3d.position3d
            }
    in
    Dict.map newEntry coords3d


textOverlay :
    Model
    -> Element msg
textOverlay model =
    let
        ( wPixels, hPixels ) =
            Rectangle2d.dimensions model.screenRectangle

        ( svgWidth, svgHeight ) =
            ( String.fromInt <| round <| Pixels.inPixels wPixels
            , String.fromInt <| round <| Pixels.inPixels hPixels
            )

        useThisRectangleForSVG =
            -- Whatever.
            Rectangle2d.from
                Point2d.origin
                (Point2d.xy wPixels hPixels)

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

        nodes2dVisible =
            --TODO: Finish SVG, reasonably neatly, considering we have two parallel position dicts.
            model.positions
                |> Dict.filter
                    -- hide things behind the camera.
                    (\id position ->
                        position.position3d |> Point3d.Projection.depth camera |> Quantity.greaterThanZero
                    )
                |> Dict.filter
                    (\id position ->
                        Rectangle2d.contains position.positionSvg useThisRectangleForSVG
                    )

        textAttributes atPoint =
            [ Svg.Attributes.fill "black"
            , Svg.Attributes.fontFamily "sans-serif"
            , Svg.Attributes.fontSize "16px"
            , Svg.Attributes.stroke "none"
            , Svg.Attributes.x (String.fromFloat (Pixels.toFloat (Point2d.xCoordinate atPoint) + 6))
            , Svg.Attributes.y (String.fromFloat (Pixels.toFloat (Point2d.yCoordinate atPoint) + 6))
            ]

        -- Create an SVG label at each place
        nodeLabels =
            model.positions
                |> Dict.map
                    (\id position ->
                        Svg.text_
                            (textAttributes position.positionSvg)
                            [ Svg.text position.label ]
                            -- Hack: flip the text upside down since our later
                            -- 'Svg.relativeTo topLeftFrame' call will flip it
                            -- back right side up
                            |> Svg.mirrorAcross
                                (Axis2d.through
                                    position.positionSvg
                                    Direction2d.x
                                )
                    )
                |> Dict.values
                |> Svg.g []
    in
    let
        topLeftFrame =
            Frame2d.atPoint
                (Point2d.xy Quantity.zero hPixels)
                |> Frame2d.reverseY
    in
    Element.html <|
        Svg.svg
            [ Svg.Attributes.width svgWidth
            , Svg.Attributes.height svgHeight
            ]
            [ Svg.relativeTo topLeftFrame nodeLabels ]
