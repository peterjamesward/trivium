module My3dScene exposing (..)

{-| This example shows how you can allow orbiting of a scene by listening for
mouse events and moving the camera accordingly.
-}

import Angle exposing (Angle)
import Axis2d
import Axis3d
import Block3d
import BoundingBox3d exposing (BoundingBox3d)
import Browser
import Camera3d exposing (Camera3d)
import Circle2d
import CollapsibleStacks
import Color
import Cone3d
import Cylinder3d
import Dagre
import Delay
import Dict exposing (Dict)
import Direction2d
import Direction3d
import Element exposing (Element, Length, fill, htmlAttribute, inFront)
import Frame2d
import Frame3d
import Geometry.Svg as Svg
import Graph exposing (..)
import Html.Events as HE
import Html.Events.Extra.Mouse as Mouse exposing (Button(..))
import Html.Events.Extra.Wheel as Wheel
import Json.Decode as Decode exposing (Decoder)
import Length exposing (Meters)
import LineSegment3d exposing (LineSegment3d)
import List.Extra
import Maybe.Extra
import Pixels exposing (Pixels, pixels)
import Plane3d
import Point2d exposing (Point2d, fromTuple, xCoordinate, yCoordinate)
import Point3d exposing (Point3d)
import Point3d.Projection
import Quantity exposing (Quantity, toFloatQuantity)
import Rectangle2d exposing (Rectangle2d)
import Scene3d exposing (..)
import Scene3d.Material as Material
import Scene3d.Mesh as Mesh exposing (Mesh, Plain)
import SketchPlane3d
import Sphere3d
import Svg
import Svg.Attributes
import Triangle3d
import Types exposing (..)
import Vector2d
import Vector3d
import Viewpoint3d


type DragAction
    = DragNone
    | DragRotate ( Float, Float )
    | DragPan ( Float, Float )


type alias Scene3dModel =
    { azimuth : Angle -- Orbiting angle of the camera around the focal point
    , elevation : Angle -- Angle of the camera up from the XY plane
    , scene : List (Entity WorldCoordinates) -- Saved Mesh values for rendering
    , zoomLevel : Float
    , focalPoint : Point3d Meters WorldCoordinates
    , dragging : DragAction
    , screenRectangle : Rectangle2d Pixels WorldCoordinates
    , labelsAndLocations : List ClickIndexEntry
    , waitingForClickDelay : Bool
    , biggestBox : BoundingBox3d Meters WorldCoordinates
    }


type RenderType
    = RenderNodeLabel String -- node label is label (for now anyway)
    | RenderEdgeLabel String String -- reified link ID, label


type Scene3dMsg
    = MouseDown Mouse.Event
    | MouseUp Mouse.Event
    | MouseMove Mouse.Event
    | MouseWheel Float
    | NoOp -- for suppressing popup context menu on right click.
    | ContentAreaChanged Int Int
    | UserClick Mouse.Event
    | ClickDelayExpired


init : ( Int, Int ) -> Scene3dModel
init ( width, height ) =
    { azimuth = Angle.degrees 45
    , elevation = Angle.degrees 30
    , scene = []
    , zoomLevel = 0.0
    , focalPoint = Point3d.origin
    , dragging = DragNone
    , screenRectangle =
        Rectangle2d.from
            (Point2d.xy (pixels <| toFloat width) Quantity.zero)
            (Point2d.xy Quantity.zero (pixels <| toFloat height))
    , labelsAndLocations = []
    , waitingForClickDelay = False
    , biggestBox = BoundingBox3d.singleton Point3d.origin
    }


projectOntoScreen : Scene3dModel -> List ClickIndexEntry -> List ClickIndexEntry
projectOntoScreen scene clicks =
    let
        ( wPixels, hPixels ) =
            Rectangle2d.dimensions scene.screenRectangle

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
                { focalPoint = scene.focalPoint
                , azimuth = scene.azimuth
                , elevation = scene.elevation
                , distance = Length.meters <| 1000 * 2 ^ scene.zoomLevel
                }

        camera =
            Camera3d.perspective
                { verticalFieldOfView = Angle.degrees 50
                , viewpoint = viewpoint
                }

        newEntry : ClickIndexEntry -> ClickIndexEntry
        newEntry old =
            { old
                | screenLocationForSVG =
                    Just <|
                        Point3d.Projection.toScreenSpace
                            camera
                            useThisRectangleForSVG
                            old.location
                , screenLocation =
                    Just <|
                        Point3d.Projection.toScreenSpace
                            camera
                            useThisRectangleForWebGL
                            old.location
            }
    in
    List.map newEntry clicks


update :
    (Scene3dMsg -> msg)
    -> Scene3dMsg
    -> Scene3dModel
    -> ( Scene3dModel, Maybe String )
update wrapper message model =
    case message of
        NoOp ->
            -- Here to allow ignoring right click.
            ( model, Nothing )

        -- Start orbiting when a mouse button is pressed
        MouseDown event ->
            let
                alternate =
                    event.keys.ctrl || event.button == SecondButton

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
                        , labelsAndLocations = projectOntoScreen model model.labelsAndLocations
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
                                , labelsAndLocations = projectOntoScreen model model.labelsAndLocations
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
                , labelsAndLocations = projectOntoScreen model model.labelsAndLocations
              }
            , Nothing
            )

        ContentAreaChanged width height ->
            ( { model
                | screenRectangle =
                    Rectangle2d.from
                        (Point2d.xy (pixels <| toFloat width) Quantity.zero)
                        (Point2d.xy Quantity.zero (pixels <| toFloat height))
                , labelsAndLocations = projectOntoScreen model model.labelsAndLocations
              }
            , Nothing
            )

        UserClick event ->
            ( model, Just <| findNearestLabel event.offsetPos model.labelsAndLocations )


type alias Nearest =
    { distance : Pixels.Pixels
    , entry : ClickIndexEntry
    }


findNearestLabel : ( Float, Float ) -> List ClickIndexEntry -> String
findNearestLabel ( x, y ) entries =
    let
        clickPoint =
            Point2d.pixels x y

        useThisOne entry =
            { distance =
                Point2d.distanceFrom
                    clickPoint
                    (Maybe.withDefault Point2d.origin entry.screenLocation)
            , entry = entry
            }

        replaceIfNearer entry best =
            let
                candidate =
                    useThisOne entry
            in
            if candidate.distance |> Quantity.lessThan best.distance then
                candidate

            else
                best
    in
    case List.head entries of
        Just first ->
            List.foldl
                replaceIfNearer
                (useThisOne first)
                (List.drop 1 entries)
                |> .entry
                |> .label

        Nothing ->
            "NOTHING FOUND"


makeMeshWithUpdatedPositionsAndStyles : Scene3dModel -> Scene3dModel
makeMeshWithUpdatedPositionsAndStyles model =
    -- This uses the previously calculated positions to render visual objects.
    --TODO: Use style info from ClickIndexEntry.
    let
        mesh : List (Entity WorldCoordinates)
        mesh =
            List.concatMap create3dMesh model.labelsAndLocations

        create3dMesh : ClickIndexEntry -> List (Entity WorldCoordinates)
        create3dMesh entry =
            if entry.isLink then
                List.Extra.zip entry.linkWaypoints (List.drop 1 entry.linkWaypoints)
                    |> List.filterMap
                        (\( fromPt, toPt ) ->
                            Cylinder3d.from fromPt toPt (Length.meters 1)
                        )
                    |> List.map (Scene3d.cylinder (Material.color Color.lightBlue))

            else
                List.singleton <|
                    makeShape entry

        ( groundPlane, bounds ) =
            renderGroundPlane model.labelsAndLocations model.biggestBox
    in
    { model
        | scene = groundPlane ++ mesh
        , biggestBox = bounds
    }


renderGroundPlane :
    List ClickIndexEntry
    -> BoundingBox3d Meters WorldCoordinates
    -> ( List (Entity WorldCoordinates), BoundingBox3d Meters WorldCoordinates )
renderGroundPlane entries biggestBox =
    case BoundingBox3d.hullOfN .location entries of
        Just isBox ->
            let
                newBiggestBox =
                    BoundingBox3d.union biggestBox isBox

                minZ =
                    -- Drop to prevent flicker.
                    BoundingBox3d.minZ biggestBox
                        |> Quantity.minus (Length.meters 6)

                { minX, maxX, minY, maxY } =
                    BoundingBox3d.extrema <|
                        BoundingBox3d.expandBy (Length.meters 100) newBiggestBox
            in
            ( [ Scene3d.quad (Material.color Color.green)
                    (Point3d.xyz minX minY minZ)
                    (Point3d.xyz minX maxY minZ)
                    (Point3d.xyz maxX maxY minZ)
                    (Point3d.xyz maxX minY minZ)
              ]
            , newBiggestBox
            )

        Nothing ->
            ( [], biggestBox )


makeShape :
    ClickIndexEntry
    -> Entity WorldCoordinates
makeShape entry =
    let
        material =
            Dict.get entry.colour Types.basicColours
                |> Maybe.withDefault Color.grey
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
    (Scene3dMsg -> msg)
    -> Scene3dModel
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
        , inFront <| textOverlay model.screenRectangle camera model
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


textOverlay :
    Rectangle2d Pixels WorldCoordinates
    -> Camera3d Meters WorldCoordinates
    -> Scene3dModel
    -> Element msg
textOverlay screenRectangle camera model =
    let
        ( wPixels, hPixels ) =
            Rectangle2d.dimensions screenRectangle

        ( svgWidth, svgHeight ) =
            ( String.fromInt <| round <| Pixels.inPixels wPixels
            , String.fromInt <| round <| Pixels.inPixels hPixels
            )

        useThisRectangleForSVG =
            -- Whatever.
            Rectangle2d.from
                Point2d.origin
                (Point2d.xy wPixels hPixels)

        nodes2dVisible =
            model.labelsAndLocations
                |> List.filter
                    -- hide things behind the camera.
                    (.location >> Point3d.Projection.depth camera >> Quantity.greaterThanZero)
                |> List.filter
                    (\entry ->
                        case entry.screenLocation of
                            Just location2d ->
                                Rectangle2d.contains location2d useThisRectangleForSVG

                            Nothing ->
                                False
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
            nodes2dVisible
                |> List.map
                    (\clickable ->
                        Svg.text_
                            (textAttributes <| Maybe.withDefault Point2d.origin clickable.screenLocationForSVG)
                            [ Svg.text clickable.label ]
                            -- Hack: flip the text upside down since our later
                            -- 'Svg.relativeTo topLeftFrame' call will flip it
                            -- back right side up
                            |> Svg.mirrorAcross
                                (Axis2d.through
                                    (Maybe.withDefault Point2d.origin clickable.screenLocationForSVG)
                                    Direction2d.x
                                )
                    )
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
