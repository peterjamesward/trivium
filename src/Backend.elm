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
      , views = Dict.empty
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
        SaveView newView ->
            let
                updated =
                    { model | views = Dict.insert newView.id newView model.views }
            in
            ( updated
            , Lamdera.broadcast (ViewList (Dict.keys updated.views))
            )

        RequestModule id ->
            case Dict.get id model.modules of
                Just triples ->
                    ( model
                    , Lamdera.sendToFrontend clientId (ModuleContent id triples)
                    )

                Nothing ->
                    ( model, Cmd.none )

        RequestModuleList ->
            ( model
            , Cmd.batch
                [ Lamdera.sendToFrontend clientId (ModuleList <| Dict.keys model.modules)
                , Lamdera.sendToFrontend clientId (ViewList <| Dict.keys model.views)
                ]
            )

        SaveModule id triples ->
            let
                updated =
                    Dict.insert id triples model.modules
            in
            ( { model | modules = updated }
            , Lamdera.broadcast (ModuleList (Dict.keys updated))
            )

        NoOpToBackend ->
            ( model, Cmd.none )


subscriptions : Model -> Sub BackendMsg
subscriptions model =
    Lamdera.onConnect (\client session -> ClientConnected)
