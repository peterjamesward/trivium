module Backend exposing (..)

import Dict exposing (..)
import DomainModel exposing (..)
import Lamdera exposing (ClientId, SessionId, sendToFrontend)
import TrivialDiagram exposing (diagram)
import Types exposing (..)


type alias Model =
    BackendModel


app =
    Lamdera.backend
        { init = init
        , update = update
        , updateFromFrontend = updateFromFrontend
        , subscriptions = \m -> Sub.none
        }


init : ( Model, Cmd BackendMsg )
init =
    ( { message = "Hello!"
      , d2Diagrams = Dict.singleton TrivialDiagram.diagram.id TrivialDiagram.diagram
      }
    , Cmd.none
    )


update : BackendMsg -> Model -> ( Model, Cmd BackendMsg )
update msg model =
    case msg of
        NoOpBackendMsg ->
            ( model, Cmd.none )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Cmd BackendMsg )
updateFromFrontend sessionId clientId msg model =
    case msg of
        NoOpToBackend ->
            ( model, Cmd.none )

        DiagramChangedAtFront diagram ->
            ( model
            , Cmd.none
            )

        AskForDiagramList ->
            ( model
            , Lamdera.sendToFrontend clientId (DiagramList <| Dict.keys model.d2Diagrams)
            )

        AskForDiagram diagramId ->
            ( model, Cmd.none )
