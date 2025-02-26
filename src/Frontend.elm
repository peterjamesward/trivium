module Frontend exposing (..)

import AsText exposing (moduleToText)
import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import CommonUiElements exposing (..)
import ContentFromTriples exposing (..)
import Dict exposing (..)
import DomainModel exposing (..)
import Element exposing (..)
import Element.Font as Font
import Element.Input as Input
import Force3DLayout
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
        , subscriptions = subscriptions
        , view = view
        }


init : Url.Url -> Nav.Key -> ( Model, Cmd FrontendMsg )
init url key =
    ( { key = key
      , time = Time.millisToPosix 0
      , message = ""
      , diagramList = []
      , moduleList = []
      , modules = Dict.empty
      , aModule = Nothing
      , diagrams = Dict.empty
      , contentEditArea = ""
      , tokenizedInput = []
      , parseStatus = Err "nothing to parse"
      , visual3d = Force3DLayout.init ( 600, 400 )
      }
    , Lamdera.sendToBackend RequestModuleList
    )


subscriptions : Model -> Sub FrontendMsg
subscriptions model =
    Sub.batch
        [ Time.every 10000 Tick
        , Force3DLayout.subscriptions Force3DMsg model.visual3d
        ]


update : FrontendMsg -> Model -> ( Model, Cmd FrontendMsg )
update msg model =
    case msg of
        Tick now ->
            ( { model | time = now }
            , Cmd.none
            )

        Force3DMsg forceMsg ->
            case model.aModule of
                Just activeModule ->
                    --TODO: Allow for multiple open modules.
                    let
                        ( newVisual, ignoreClick ) =
                            Force3DLayout.update forceMsg activeModule model.visual3d
                    in
                    ( { model | visual3d = newVisual }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        UserClickedModuleId mId ->
            ( model
            , Lamdera.sendToBackend (RequestModule mId)
            )

        UserClickedSave ->
            case ( model.aModule, model.parseStatus ) of
                ( Just m, Ok triples ) ->
                    ( model, Lamdera.sendToBackend (SaveModule m.id triples) )

                _ ->
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
            ( { model
                | contentEditArea = content
                , parseStatus = Err "not parsed"
              }
            , Cmd.none
            )

        UserClickedParse ->
            let
                tokens =
                    Lexer.tokenize model.contentEditArea

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
                | tokenizedInput = tokens
                , parseStatus = parse
                , aModule = aModule
                , visual3d =
                    case aModule of
                        Just isModule ->
                            Force3DLayout.computeInitialPositions isModule model.visual3d

                        Nothing ->
                            model.visual3d
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

        ModuleContent id triples ->
            let
                newModule =
                    -- Debug.log "MODULE" <|
                    moduleFromTriples triples
            in
            ( { model
                | aModule = Just newModule
                , visual3d = Force3DLayout.computeInitialPositions newModule model.visual3d
                , contentEditArea = AsText.moduleToText newModule
              }
            , Cmd.none
            )


view : Model -> Browser.Document FrontendMsg
view model =
    { title = "Welcome to the Trivium"
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
                        { label = text "Parse"
                        , onPress = Just UserClickedParse
                        }
                    , case model.parseStatus of
                        Ok _ ->
                            Input.button CommonUiElements.buttonStyles
                                { label = text "Save"
                                , onPress = Just UserClickedSave
                                }

                        Err error ->
                            CommonUiElements.disabledButton error
                    ]
                , column columnStyles
                    [ -- ViewCatalogue.showCatalogue model.aModule
                      Force3DLayout.view Force3DMsg model.visual3d
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
