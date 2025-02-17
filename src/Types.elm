module Types exposing (..)

import Browser exposing (UrlRequest)
import Browser.Navigation exposing (Key)
import Dict exposing (..)
import DomainModel exposing (..)
import Url exposing (Url)


type alias FrontendModel =
    { key : Key
    , message : String
    , diagramList : List DiagramId
    , diagram : Maybe Diagram
    , asText : Maybe String

    -- To add: Scene3DModel, File loading stuff.
    }


type alias BackendModel =
    { message : String
    , diagrams : Dict DiagramId Diagram
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | UserSelectedDiagram DiagramId
    | NoOpFrontendMsg


type ToBackend
    = NoOpToBackend
    | DiagramChangedAtFront Diagram -- leaves some room for optimisation!
    | AskForDiagramList
    | AskForDiagram DiagramId


type BackendMsg
    = NoOpBackendMsg


type ToFrontend
    = NoOpToFrontend
    | DiagramList (List DiagramId)
    | DiagramContent Diagram -- sub-optimal, may want to know clientId to avoid feedback loop.
