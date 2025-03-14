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
import File exposing (..)
import File.Download as Download exposing (..)
import File.Select as Select exposing (..)
import Force3DLayout
import Lamdera
import Lexer exposing (..)
import Maybe.Extra exposing (join)
import Parser exposing (..)
import Set exposing (..)
import Task exposing (..)
import Time exposing (..)
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
      , inspectedItem = Nothing
      , activeView = Nothing
      , selectedTypes = Set.empty
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
        UserClickedHideAllTypes ->
            let
                newModel =
                    { model | selectedTypes = Set.empty }
            in
            ( { newModel
                | visual3d =
                    Force3DLayout.computeInitialPositions
                        (applyViewFilters newModel newModel.effectiveModule)
                        newModel.visual3d
              }
            , Cmd.none
            )

        UserClickedShowAllTypes ->
            let
                newModel =
                    { model
                        | selectedTypes =
                            model.effectiveModule.classes
                                |> Dict.keys
                                |> Set.fromList
                    }
            in
            ( { newModel
                | visual3d =
                    Force3DLayout.computeInitialPositions
                        (applyViewFilters newModel newModel.effectiveModule)
                        newModel.visual3d
              }
            , Cmd.none
            )

        UserTogglesTypeSelection typeId selected ->
            let
                newModel =
                    { model
                        | selectedTypes =
                            if Set.member typeId model.selectedTypes then
                                Set.remove typeId model.selectedTypes

                            else
                                Set.insert typeId model.selectedTypes
                    }
            in
            ( { newModel
                | visual3d =
                    Force3DLayout.computeInitialPositions
                        (applyViewFilters newModel newModel.effectiveModule)
                        newModel.visual3d
              }
            , Cmd.none
            )

        FileLoaded text ->
            ( { model | contentEditArea = text }
            , Cmd.none
            )

        FileSelected file ->
            ( model, Task.perform FileLoaded (File.toString file) )

        UserClickedLoadFile ->
            ( model
            , Select.file [] FileSelected
            )

        UserClickedDownload ->
            let
                filename =
                    model.effectiveModule.id ++ ".txt"
            in
            if String.length model.contentEditArea > 0 then
                ( model
                , Download.string
                    filename
                    "text/trivium"
                    model.contentEditArea
                )

            else
                ( model, Cmd.none )

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
                , visual3d =
                    Force3DLayout.computeInitialPositions
                        (applyViewFilters model effective)
                        model.visual3d
                , showRawTriples = isRaw
              }
            , Cmd.none
            )

        UserTogglesModuleSelection moduleId active ->
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
                            , effectiveModule = effective
                            , visual3d =
                                Force3DLayout.computeInitialPositions
                                    (applyViewFilters model effective)
                                    model.visual3d
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
                    , effectiveModule = effective
                    , visual3d =
                        Force3DLayout.computeInitialPositions
                            (applyViewFilters model effective)
                            model.visual3d
                  }
                , Cmd.none
                )

        Tick now ->
            ( { model | time = now }
            , Cmd.none
            )

        Force3DMsg forceMsg ->
            let
                ( newVisual, nearestItem ) =
                    Force3DLayout.update forceMsg model.effectiveModule model.visual3d
            in
            ( { model
                | visual3d = newVisual
                , inspectedItem =
                    nearestItem |> Maybe.Extra.orElse model.inspectedItem
              }
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
                ( Just m, Ok triples ) ->
                    let
                        loadedModules =
                            Dict.insert m.id triples model.loadedModules

                        effective =
                            effectiveModule loadedModules
                    in
                    ( { model
                        | loadedModules = loadedModules
                        , effectiveModule = effective
                        , selectedModules = Set.insert m.id model.selectedModules
                        , visual3d =
                            Force3DLayout.computeInitialPositions
                                (applyViewFilters model effective)
                                model.visual3d
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
                    Debug.log "LEXER" <|
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


applyViewFilters : Model -> Module -> Module
applyViewFilters model aModule =
    -- Show only instance of types that are selected for viewing.
    { aModule
        | classes =
            aModule.classes
                |> Dict.filter (\id _ -> Set.member id model.selectedTypes)
        , nodes =
            aModule.nodes
                |> Dict.filter
                    (\id node ->
                        node.class
                            |> Maybe.andThen (\class -> Just <| Set.member class model.selectedTypes)
                            |> Maybe.withDefault True
                    )
        , links =
            aModule.links
                |> Dict.filter
                    (\id link ->
                        link.class
                            |> Maybe.andThen (\class -> Just <| Set.member class model.selectedTypes)
                            |> Maybe.withDefault True
                    )
    }


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
                , visual3d =
                    Force3DLayout.computeInitialPositions
                        (applyViewFilters model newModule)
                        model.visual3d
              }
            , Cmd.none
            )


view : Model -> Browser.Document FrontendMsg
view model =
    let
        editArea =
            let
                buttons =
                    row neatRowStyles
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
                        , Input.button CommonUiElements.buttonStyles
                            { label = text "Download"
                            , onPress = Just UserClickedDownload
                            }
                        , Input.button CommonUiElements.buttonStyles
                            { label = text "Load file"
                            , onPress = Just UserClickedLoadFile
                            }
                        ]
            in
            column columnStyles
                [ text "Please input something."
                , Input.multiline [ height fill ]
                    { onChange = UserUpdatedContent
                    , text = model.contentEditArea
                    , placeholder = Nothing
                    , label = Input.labelHidden "content"
                    , spellcheck = False
                    }
                , buttons
                ]

        viewOptions =
            row neatRowStyles
                [ Input.checkbox [ centerY ]
                    { onChange = UserTogglesRawMode
                    , icon = Input.defaultCheckbox
                    , checked = model.showRawTriples
                    , label = Input.labelRight [] (text "Show raw triples")
                    }
                ]
    in
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
                    [ inspector model
                    , viewOptions
                    , editArea
                    ]
                , Force3DLayout.view Force3DMsg model.visual3d
                , column columnStyles
                    [ modulesTable model.moduleList model.selectedModules
                    , typesTable model
                    ]
                ]
        ]
    }


inspector : Model -> Element FrontendMsg
inspector model =
    -- reveal information about item under mouse or clicked on (this will come out in the wash)
    let
        headerAttrs =
            [ Border.widthEach { bottom = 1, top = 0, left = 0, right = 0 } ]

        attributeTable : InnerDict -> Element FrontendMsg
        attributeTable attributes =
            column columnStyles
                [ row [ width fill ]
                    [ el ((width <| fillPortion 1) :: headerAttrs) <| text "Key"
                    , el ((width <| fillPortion 4) :: headerAttrs) <| text "Value"
                    ]
                , el [ width fill ] <|
                    table
                        [ width fill
                        , scrollbarY
                        , spacing 1
                        ]
                        { data = Dict.toList attributes
                        , columns =
                            [ { header = none
                              , width = fillPortion 1
                              , view = \( k, v ) -> el [ padding 2 ] <| text k
                              }
                            , { header = none
                              , width = fillPortion 4
                              , view = \( k, v ) -> el [ padding 2 ] <| text <| String.join ", " <| Set.toList v
                              }
                            ]
                        }
                ]
    in
    case model.inspectedItem of
        Just anItem ->
            case ( Dict.get anItem model.effectiveModule.nodes, Dict.get anItem model.effectiveModule.links ) of
                ( Just node, _ ) ->
                    column columnStyles
                        [ el [ Font.bold, padding 2 ] <| text node.id
                        , attributeTable node.attributes
                        ]

                ( _, Just link ) ->
                    column columnStyles
                        [ el [ Font.bold, padding 2 ] <| text link.label
                        , attributeTable link.attributes
                        ]

                _ ->
                    text "What is that?"

        Nothing ->
            text "Nothing selected"


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


typesTable : Model -> Element FrontendMsg
typesTable model =
    let
        headerAttrs =
            [ Border.widthEach { bottom = 1, top = 0, left = 0, right = 0 } ]

        includable item =
            Input.checkbox [ centerY ]
                { onChange = UserTogglesTypeSelection item
                , icon = Input.defaultCheckbox
                , checked = Set.member item model.selectedTypes
                , label = Input.labelHidden "include"
                }
    in
    column
        columnStyles
        [ row neatRowStyles
            [ simpleButton UserClickedShowAllTypes "Show all"
            , simpleButton UserClickedHideAllTypes "Hide all"
            ]
        , row [ width fill ]
            [ el ((width <| fillPortion 1) :: headerAttrs) <| text "Show"
            , el ((width <| fillPortion 6) :: headerAttrs) <| text "Type"
            ]

        -- workaround for a bug: it's necessary to wrap `table` in an `el`
        -- to get table height attribute to apply
        , el [ width fill ] <|
            table
                [ width fill
                , scrollbarY
                , spacing 1
                ]
                { data = model.effectiveModule.classes |> Dict.keys
                , columns =
                    [ { header = none
                      , width = fillPortion 1
                      , view = includable
                      }
                    , { header = none
                      , width = fillPortion 6
                      , view = text
                      }
                    ]
                }
        ]
