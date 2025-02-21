module Frontend exposing (..)

import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import CommonUiElements exposing (..)
import Dict exposing (..)
import DomainModel exposing (..)
import Element exposing (..)
import Element.Font as Font
import Element.Input as Input
import Html
import Html.Attributes as Attr
import Lamdera
import Lexer exposing (..)
import Parser exposing (..)
import Types exposing (..)
import Url
import Time exposing (..)


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
      , modulesList = []
      , modules = Dict.empty
      , diagrams = Dict.empty
      , contentEditArea = ""
      , tokenizedInput = []
      , visual = Nothing
      , parseStatus = Err "nothing to parse"
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

        UserUpdatedContent content ->
            let
                tokens =
                    Lexer.tokenize content

                parse = Parser.parseTokensToTriples (Time.millisToPosix 122) tokens

                _ =
                    Debug.log "Parse" parse
            in
            ( { model
                | contentEditArea = content
                , tokenizedInput = tokens
                , parseStatus = parse
              }
            , Cmd.none
            )


updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
updateFromBackend msg model =
    case msg of
        NoOpToFrontend ->
            ( model, Cmd.none )

        DiagramContent diagram ->
            ( model
            , Cmd.none
            )

        DiagramList diagramIds ->
            ( { model | diagramList = diagramIds }
            , Cmd.none
            )


view : Model -> Browser.Document FrontendMsg
view model =
    { title = "PEATmagic"
    , body =
        [ layout
            [ width fill
            , height fill
            , Font.size 12
            , Font.family
                [ Font.typeface "Open Sans"
                , Font.sansSerif
                ]
            ]
          <|
            row columnStyles
                [ column columnStyles
                    [ text "Please input something."
                    , Input.multiline [ height fill ]
                        { onChange = UserUpdatedContent
                        , text = model.contentEditArea
                        , placeholder = Nothing
                        , label = Input.labelHidden "content"
                        , spellcheck = False
                        }
                    ]
                , column columnStyles
                    [ text "Reserved for future functionality."
                    ]
                ]
        ]
    }
