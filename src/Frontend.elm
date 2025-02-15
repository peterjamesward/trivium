module Frontend exposing (..)

import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import CommonUiElements exposing (..)
import DomainModel exposing (..)
import Element exposing (..)
import Element.Input as Input
import Html
import Html.Attributes as Attr
import Lamdera
import Types exposing (..)
import Url


type alias Model =
    FrontendModel


app =
    Lamdera.frontend
        { init = init
        , onUrlRequest = UrlClicked
        , onUrlChange = UrlChanged
        , update = update
        , updateFromBackend = updateFromBackend
        , subscriptions = \m -> Sub.none
        , view = view
        }


init : Url.Url -> Nav.Key -> ( Model, Cmd FrontendMsg )
init url key =
    ( { key = key
      , message = ""
      , diagramList = []
      , d2Diagram = Nothing
      }
    , Lamdera.sendToBackend AskForDiagramList
    )


update : FrontendMsg -> Model -> ( Model, Cmd FrontendMsg )
update msg model =
    case msg of
        UserSelectedDiagram id ->
            ( model, Lamdera.sendToBackend (AskForDiagram id) )

        UrlClicked urlRequest ->
            case urlRequest of
                Internal url ->
                    ( model
                    , Nav.pushUrl model.key (Url.toString url)
                    )

                External url ->
                    ( model
                    , Nav.load url
                    )

        UrlChanged url ->
            ( model, Cmd.none )

        NoOpFrontendMsg ->
            ( model, Cmd.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
updateFromBackend msg model =
    case msg of
        NoOpToFrontend ->
            ( model, Cmd.none )

        UpdatedDiagram diagram ->
            ( { model | d2Diagram = Just diagram }
            , Cmd.none
            )

        DiagramList diagramIds ->
            ( { model | diagramList = diagramIds }
            , Cmd.none
            )


view : Model -> Browser.Document FrontendMsg
view model =
    let
        selectDiagram id =
            simpleButton (UserSelectedDiagram id) id
    in
    { title = "d2Magic starts here"
    , body =
        [ Element.layout [ width fill, height fill, padding 5 ] <|
            Element.column [ height fill, spacing 5, padding 5 ]
                (List.map selectDiagram model.diagramList)
        ]
    }
