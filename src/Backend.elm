module Backend exposing (..)

import Dict exposing (..)
import DomainModel exposing (..)
import Lamdera exposing (ClientId, SessionId, sendToFrontend)
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
      , modules = Dict.empty
      , diagrams = Dict.empty
      }
    , Cmd.none
    )


update : BackendMsg -> Model -> ( Model, Cmd BackendMsg )
update msg model =
    case msg of
        NoOpBackendMsg ->
            ( model, Cmd.none )

        ClientConnected ->
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
            , Lamdera.sendToFrontend clientId (DiagramList <| Dict.keys model.diagrams)
            )

        AskForDiagram diagramId ->
            ( model
            , case Dict.get diagramId model.diagrams of
                Just diagram ->
                    Lamdera.sendToFrontend clientId (DiagramContent diagram)

                Nothing ->
                    Cmd.none
            )


subscriptions : Model -> Sub BackendMsg
subscriptions model =
    Lamdera.onConnect (\client session -> ClientConnected)
