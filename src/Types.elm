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
    , d2Diagram : Maybe D2Diagram

    -- To add: Scene3DModel, File loading stuff.
    }


type alias BackendModel =
    { message : String
    , d2Diagrams : Dict DiagramId D2Diagram
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | UserSelectedDiagram DiagramId
    | NoOpFrontendMsg


type ToBackend
    = NoOpToBackend
    | DiagramChangedAtFront D2Diagram -- leaves some room for optimisation!
    | AskForDiagramList
    | AskForDiagram DiagramId


type BackendMsg
    = NoOpBackendMsg


type ToFrontend
    = NoOpToFrontend
    | DiagramList (List DiagramId)
    | UpdatedDiagram D2Diagram -- sub-optimal, may want to know clientId to avoid feedback loop.
