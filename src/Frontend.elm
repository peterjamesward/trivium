module Frontend exposing (..)

import AsText exposing (moduleToText)
import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import CommonUiElements exposing (..)
import ContentFromTriples exposing (..)
import Dict exposing (..)
import DomainModel exposing (..)
import Element exposing (..)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Force3DLayout
import Html
import Html.Attributes as Attr
import Lamdera
import Lexer exposing (..)
import Parser exposing (..)
import Set exposing (..)
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
      , layoutList = []
      , moduleList = []
      , editingModule = Nothing
      , effectiveModule = DomainModel.emptyModule
      , contentEditArea = ""
      , tokenizedInput = []
      , parseStatus = Err "nothing to parse"
      , visual3d = Force3DLayout.init ( 600, 800 )
      , selectedModules = Set.empty
      , loadedModules = Dict.empty
      , standbyModules = Dict.empty
      , showRawTriples = False
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
    let
        effectiveModule loaded =
            loaded
                |> Dict.values
                |> List.foldl Set.union Set.empty
                |> moduleFromTriples

        rawModule loaded =
            loaded
                |> Dict.values
                |> List.foldl Set.union Set.empty
                |> rawFromTriples
    in
    case msg of
        UserTogglesRawMode isRaw ->
            let
                effective =
                    if isRaw then
                        rawModule model.loadedModules

                    else
                        effectiveModule model.loadedModules
            in
            ( { model
                | effectiveModule = effective
                , visual3d = Force3DLayout.computeInitialPositions effective model.visual3d
                , showRawTriples = isRaw
              }
            , Cmd.none
            )

        UserTogglesModuleSelection moduleId active ->
            --TODO: always regenerate visuals with currently loaded modules...
            if active then
                -- If we have a copy locally, use it straight away.
                case Dict.get moduleId model.standbyModules of
                    Just standby ->
                        let
                            loadedModules =
                                Dict.insert moduleId standby model.loadedModules

                            effective =
                                effectiveModule loadedModules
                        in
                        ( { model
                            | selectedModules = Set.insert moduleId model.selectedModules
                            , loadedModules = loadedModules
                            , standbyModules = Dict.remove moduleId model.standbyModules
                            , effectiveModule = effectiveModule loadedModules
                            , visual3d = Force3DLayout.computeInitialPositions effective model.visual3d
                          }
                        , Cmd.none
                        )

                    Nothing ->
                        -- Order it up from the archives.
                        ( { model | selectedModules = Set.insert moduleId model.selectedModules }
                        , Lamdera.sendToBackend (RequestModule moduleId)
                        )

            else
                let
                    loadedModules =
                        Dict.remove moduleId model.loadedModules

                    effective =
                        effectiveModule loadedModules
                in
                ( { model
                    | selectedModules = Set.remove moduleId model.selectedModules
                    , loadedModules = loadedModules
                    , standbyModules =
                        case Dict.get moduleId model.loadedModules of
                            Just loaded ->
                                Dict.insert moduleId loaded model.standbyModules

                            Nothing ->
                                model.standbyModules
                    , effectiveModule = effectiveModule loadedModules
                    , visual3d = Force3DLayout.computeInitialPositions effective model.visual3d
                  }
                , Cmd.none
                )

        Tick now ->
            ( { model | time = now }
            , Cmd.none
            )

        Force3DMsg forceMsg ->
            let
                ( newVisual, ignoreClick ) =
                    Force3DLayout.update forceMsg model.effectiveModule model.visual3d
            in
            ( { model | visual3d = newVisual }
            , Cmd.none
            )

        UserClickedModuleId mId ->
            -- If loaded, module is move into the editing area.
            case Dict.get mId model.loadedModules of
                Just triples ->
                    let
                        asModule =
                            ContentFromTriples.moduleFromTriples triples
                    in
                    ( { model
                        | editingModule = Just asModule
                        , contentEditArea = AsText.moduleToText asModule
                        , parseStatus = Err "loaded"
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model
                    , Cmd.none
                    )

        UserClickedSave ->
            case ( model.editingModule, model.parseStatus ) of
                --TODO: update cached copy and regenerate visuals.
                ( Just m, Ok triples ) ->
                    let
                        loadedModules =
                            Dict.insert m.id triples model.loadedModules

                        effective =
                            effectiveModule loadedModules
                    in
                    ( { model
                        | loadedModules = loadedModules
                        , effectiveModule = effectiveModule loadedModules
                        , visual3d = Force3DLayout.computeInitialPositions effective model.visual3d
                      }
                    , Lamdera.sendToBackend (SaveModule m.id triples)
                    )

                _ ->
                    ( model, Cmd.none )

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
                    Parser.parseTokensToTriples tokens

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
                , editingModule = aModule
              }
            , Cmd.none
            )


updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
updateFromBackend msg model =
    case msg of
        NoOpToFrontend ->
            ( model, Cmd.none )

        ModuleList moduleIds ->
            ( { model | moduleList = moduleIds }
            , Cmd.none
            )

        ModuleContent id triples ->
            let
                withAddedModule =
                    Dict.insert id triples model.loadedModules

                allTriples =
                    withAddedModule
                        |> Dict.values
                        |> List.foldl Set.union Set.empty

                newModule =
                    moduleFromTriples allTriples
            in
            ( { model
                | loadedModules = withAddedModule
                , effectiveModule = newModule
                , visual3d = Force3DLayout.computeInitialPositions newModule model.visual3d
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
                    [ row neatRowStyles
                        [ Input.checkbox [ centerY ]
                            { onChange = UserTogglesRawMode
                            , icon = Input.defaultCheckbox
                            , checked = model.showRawTriples
                            , label = Input.labelRight [] (text "Show raw triples")
                            }
                        ]
                    , text "Please input something."
                    , Input.multiline [ height fill ]
                        { onChange = UserUpdatedContent
                        , text = model.contentEditArea
                        , placeholder = Nothing
                        , label = Input.labelHidden "content"
                        , spellcheck = False
                        }
                    , row neatRowStyles
                        [ Input.button CommonUiElements.buttonStyles
                            { label = text "Validate"
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
                    ]
                , Force3DLayout.view Force3DMsg model.visual3d
                , column columnStyles
                    [ modulesTable model.moduleList model.selectedModules
                    ]
                ]
        ]
    }


modulesTable :
    List ModuleId
    -> Set ModuleId
    -> Element FrontendMsg
modulesTable modules selected =
    let
        headerAttrs =
            [ Border.widthEach { bottom = 1, top = 0, left = 0, right = 0 } ]

        selectable item =
            if Set.member item selected then
                simpleButton (UserClickedModuleId item) "edit"

            else
                disabledButton "not loaded"

        includable item =
            Input.checkbox [ centerY ]
                { onChange = UserTogglesModuleSelection item
                , icon = Input.defaultCheckbox
                , checked = Set.member item selected
                , label = Input.labelHidden "include"
                }
    in
    column
        columnStyles
        [ row [ width fill ]
            [ el ((width <| fillPortion 1) :: headerAttrs) <| text "Show"
            , el ((width <| fillPortion 4) :: headerAttrs) <| text "Module"
            , el ((width <| fillPortion 1) :: headerAttrs) <| text "Edit"
            ]

        -- workaround for a bug: it's necessary to wrap `table` in an `el`
        -- to get table height attribute to apply
        , el [ width fill ] <|
            table
                [ width fill
                , scrollbarY
                , spacing 1
                ]
                { data = modules
                , columns =
                    [ { header = none
                      , width = fillPortion 1
                      , view = includable
                      }
                    , { header = none
                      , width = fillPortion 4
                      , view = text
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = selectable
                      }
                    ]
                }
        ]
