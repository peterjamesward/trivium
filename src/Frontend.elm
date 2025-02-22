module Frontend exposing (..)

import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import CommonUiElements exposing (..)
import ContentFromTriples exposing (..)
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
import Time exposing (..)
import Types exposing (..)
import Url
import ViewCatalogue exposing (..)


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
      , moduleList = []
      , modules = Dict.empty
      , aModule = Nothing
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
        UserClickedModuleId mId ->
            ( model
            , Lamdera.sendToBackend (RequestModule mId)
            )

        UserClickedSave ->
            case model.aModule of
                Just m ->
                    ( model, Lamdera.sendToBackend (SaveModule m) )

                Nothing ->
                    ( model, Cmd.none )

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

                parse =
                    Parser.parseTokensToTriples (Time.millisToPosix 122) tokens

                aModule =
                    case parse of
                        Ok triple ->
                            Just <| ContentFromTriples.moduleFromTriples triple

                        _ ->
                            Nothing
            in
            ( { model
                | contentEditArea = content
                , tokenizedInput = tokens
                , parseStatus = parse
                , aModule = aModule
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

        ModuleList moduleIds ->
            ( { model | moduleList = moduleIds }
            , Cmd.none
            )

        ModuleContent m ->
            ( { model | aModule = Just m }
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
                    , Input.button CommonUiElements.buttonStyles
                        { label = text "Save"
                        , onPress = Just UserClickedSave
                        }
                    ]
                , column columnStyles
                    [ ViewCatalogue.showCatalogue model.aModule
                    ]
                , column columnStyles
                    [ model.moduleList
                        |> List.map
                            (\moduleId ->
                                Input.button CommonUiElements.buttonStyles
                                    { label = text moduleId
                                    , onPress = Just (UserClickedModuleId moduleId)
                                    }
                            )
                        |> wrappedRow [ spacing 5, padding 5, width fill ]
                    ]
                ]
        ]
    }
