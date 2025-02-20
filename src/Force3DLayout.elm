module Force3DLayout exposing (..)

import Angle
import Arc3d
import Camera3d
import Circle3d
import Dict exposing (Dict)
import Direction3d
import Element exposing (..)
import Length exposing (Meters)
import List.Extra
import Maybe.Extra
import My3dScene
import Pixels
import Point2d
import Point3d exposing (Point3d)
import Point3d.Projection
import Polyline3d
import Quantity
import Rectangle2d
import Set exposing (Set)
import Time
import Types exposing (..)
import Vector3d exposing (Vector3d)
import Viewpoint3d


type alias Model =
    { repulsion : Float -- relative node repulsion force
    , tension : Float -- relative link pull force
    , fieldStrength : Float -- relative field alignment force for links
    , gravitationalConstant : Float
    , timeDelta : Float -- how much to apply force each tick.
    , positions : Dict String (Point3d Meters WorldCoordinates)

    --, links : Dict String (Dict String String) -- set of (p,o) for each `s`. Helps with forces model.
    , scene3d : My3dScene.Scene3dModel -- seems that we can reuse this, may need refactor later.
    , nodeTypes : Dict String (Maybe String)
    , timeLayoutBegan : Time.Posix
    , lastTick : Time.Posix
    , semNodes : Dict NodeId SemanticNode
    , semLinks : Dict LinkId ReifiedLink
    }


type Msg
    = AnimationTick Time.Posix
    | SetRepulsion Float
    | SetTension Float
    | SetFieldStrength Float
    | ChangeContent
    | SceneMsg My3dScene.Scene3dMsg


init : ( Int, Int ) -> Model
init contentArea =
    { repulsion = 1.0
    , tension = 3.0
    , fieldStrength = 0.1
    , gravitationalConstant = 0.05 -- avoid infinite expansion
    , timeDelta = 0.1
    , positions = Dict.empty

    --, links = Dict.empty
    , scene3d = My3dScene.init contentArea
    , nodeTypes = Dict.empty
    , timeLayoutBegan = Time.millisToPosix 0
    , lastTick = Time.millisToPosix 0
    , semNodes = Dict.empty
    , semLinks = Dict.empty
    }


initialiseWithSemantics :
    Dict NodeId SemanticNode
    -> Dict LinkId ReifiedLink
    -> Model
    -> Model
initialiseWithSemantics semNodes semLinks model =
    -- Start by distributing nodes arbitrarily (not randomly) around a circle.
    let
        nodeLocations : List (Point3d Meters WorldCoordinates)
        nodeLocations =
            Circle3d.withRadius (Length.meters 100) Direction3d.z Point3d.origin
                |> Circle3d.toArc
                |> Arc3d.segments (Dict.size semNodes)
                |> Polyline3d.vertices

        positions =
            List.Extra.zip (Dict.keys semNodes) nodeLocations
                |> Dict.fromList

        scene =
            My3dScene.makeMeshWithUpdatedPositionsAndStyles model.scene3d
    in
    { model
        | positions = positions
        , scene3d = scene
        , timeLayoutBegan = model.lastTick
        , semNodes = semNodes
        , semLinks = semLinks
    }


update : Msg -> Model -> ( Model, Maybe String )
update msg model =
    case msg of
        AnimationTick now ->
            ( { model | lastTick = now }
                |> (if Time.posixToMillis now < Time.posixToMillis model.timeLayoutBegan + 30000 then
                        applyForces

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

        SceneMsg scene3dMsg ->
            let
                ( newScene, clicked ) =
                    -- Need to reposition the SVG.
                    My3dScene.update
                        SceneMsg
                        scene3dMsg
                        model.scene3d
            in
            ( { model | scene3d = newScene }
            , clicked
            )


view : (Msg -> msg) -> Model -> Element msg
view wrapMsg model =
    My3dScene.view (wrapMsg << SceneMsg) model.scene3d


renderGraph : Model -> Model
renderGraph model =
    { model
        | scene3d = My3dScene.makeMeshWithUpdatedPositionsAndStyles model.scene3d
    }


storeLabelPlacements : Model -> Model
storeLabelPlacements model =
    let
        scene =
            model.scene3d

        newScene =
            { scene | labelsAndLocations = nodesForDrawing ++ linksForDrawing }

        nodesForDrawing : List ClickIndexEntry
        nodesForDrawing =
            Dict.foldl makeClickEntryForRealNode [] model.semNodes

        linksForDrawing : List ClickIndexEntry
        linksForDrawing =
            Dict.foldl makeClickEntryForLinks [] model.semLinks

        makeClickEntryForRealNode :
            NodeId
            -> SemanticNode
            -> List ClickIndexEntry
            -> List ClickIndexEntry
        makeClickEntryForRealNode nodeId semNode clickers =
            let
                location =
                    Dict.get semNode.id model.positions |> Maybe.withDefault Point3d.origin

                newEntry =
                    { nodeId = semNode.id
                    , label = semNode.id
                    , isLink = False
                    , location = location
                    , linkWaypoints = []
                    , screenLocationForSVG = Nothing
                    , screenLocation = Nothing
                    , shape = semNode.shape
                    , colour = semNode.colour
                    }
            in
            newEntry :: clickers

        makeClickEntryForLinks :
            LinkId
            -> ReifiedLink
            -> List ClickIndexEntry
            -> List ClickIndexEntry
        makeClickEntryForLinks linkId semLink clickers =
            case ( Dict.get semLink.subject model.positions, Dict.get semLink.object model.positions ) of
                ( Just sourcePosition, Just objectPosition ) ->
                    let
                        location =
                            Point3d.midpoint sourcePosition objectPosition

                        newEntry =
                            { nodeId = semLink.subject
                            , label = semLink.relation
                            , isLink = True
                            , location = location
                            , linkWaypoints = [ sourcePosition, objectPosition ]
                            , screenLocation = Nothing
                            , screenLocationForSVG = Nothing
                            , shape = "TBD"
                            , colour = "blue"
                            }
                    in
                    newEntry :: clickers

                _ ->
                    clickers
    in
    { model | scene3d = newScene }


subscriptions : (Msg -> msg) -> Model -> Sub msg
subscriptions msgWrapper model =
    if Time.posixToMillis model.lastTick < Time.posixToMillis model.timeLayoutBegan + 30000 then
        Time.every 100 (msgWrapper << AnimationTick)

    else
        Sub.none


applyForces : Model -> Model
applyForces model =
    -- Finally, this is what we are here for.
    -- May be able to do this just by successive transforms of the node position dict.
    -- 1. Get the repulsion forces.
    -- 2. Attraction.
    -- 3. Alignment with fields (from styles).
    -- 4. Update positions by applying net force.
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
                        , Vector3d.from position Point3d.origin |> Vector3d.multiplyBy model.gravitationalConstant
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
            model.semLinks
                |> Dict.foldl
                    (\linkId reifiedLink forcesDict ->
                        let
                            ( s, o ) =
                                ( reifiedLink.subject, reifiedLink.object )
                        in
                        case ( Dict.get s forcesDict, Dict.get o forcesDict ) of
                            ( Just ( sPos, sForce ), Just ( oPos, oForce ) ) ->
                                let
                                    attraction =
                                        Point3d.distanceFrom sPos oPos
                                            |> Quantity.minus (Length.meters 30)
                                            |> Quantity.max Quantity.zero

                                    forceOnS =
                                        Vector3d.from sPos oPos
                                            |> Vector3d.scaleTo attraction

                                    forceOnO =
                                        Vector3d.from oPos sPos
                                            |> Vector3d.scaleTo attraction
                                in
                                forcesDict
                                    |> Dict.insert s ( sPos, Vector3d.plus sForce forceOnS )
                                    |> Dict.insert o ( oPos, Vector3d.plus oForce forceOnO )

                            _ ->
                                forcesDict
                    )
                    withRepulsion

        withFields : Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
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
            model.semLinks
                |> Dict.foldl addRotationalForcesIfLinkHasDirection withAttraction

        addRotationalForcesIfLinkHasDirection :
            LinkId
            -> ReifiedLink
            -> Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
            -> Dict String ( Point3d Meters WorldCoordinates, Vector3d Meters WorldCoordinates )
        addRotationalForcesIfLinkHasDirection linkId reified collector =
            -- Should cater for reified links but also simple links where the label is the type.
            -- (which should be covered by the nodesTypes.)
            case
                ( Dict.get reified.subject collector
                , Dict.get reified.object collector
                )
            of
                ( Just ( sPos, sForce ), Just ( oPos, oForce ) ) ->
                    case Dict.get (String.toUpper reified.direction) directionVectors of
                        Just desiredDirection ->
                            -- Note that these forces apply to the "actual" subject and object.
                            let
                                currentVector =
                                    Vector3d.from sPos oPos

                                desiredVector =
                                    Vector3d.withLength
                                        (Vector3d.length currentVector)
                                        desiredDirection

                                correctiveForceAtStart =
                                    desiredVector
                                        |> Vector3d.minus currentVector
                                        |> Vector3d.multiplyBy model.fieldStrength

                                correctiveForceAEnd =
                                    Vector3d.reverse correctiveForceAtStart
                                        |> Vector3d.multiplyBy model.fieldStrength
                            in
                            collector
                                |> Dict.insert reified.subject ( sPos, Vector3d.plus sForce correctiveForceAtStart )
                                |> Dict.insert reified.object ( oPos, Vector3d.plus oForce correctiveForceAEnd )

                        _ ->
                            collector

                _ ->
                    collector

        newPositions : Dict String (Point3d Meters WorldCoordinates)
        newPositions =
            withFields
                |> Dict.map
                    (\thisNode ( position, force ) ->
                        position
                            |> Point3d.translateBy (Vector3d.scaleBy model.timeDelta force)
                    )
    in
    { model | positions = newPositions }
        |> storeLabelPlacements
        |> renderGraph
