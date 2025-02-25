module Types exposing (..)

import Browser exposing (UrlRequest)
import Browser.Navigation exposing (Key)
import Dict exposing (..)
import DomainModel exposing (..)
import Force3DLayout
import LexerTypes exposing (..)
import Parser exposing (..)
import Set exposing (..)
import Time exposing (Posix)
import Url exposing (Url)


type alias FrontendModel =
    { key : Key
    , time : Time.Posix
    , message : String
    , diagramList : List DiagramId -- full list of what is in the backend
    , moduleList : List ModuleId -- ditto
    , modules : Dict ModuleId Module -- loaded and active.
    , aModule : Maybe Module -- being edited.
    , diagrams : Dict DiagramId Diagram
    , contentEditArea : String -- place to enter and edit modules and diagrams
    , tokenizedInput : List Token -- live parsing and errors.
    , parseStatus : Result String (Set Triple)
    , visual3d : Force3DLayout.Model
    }


type alias BackendModel =
    { message : String
    , modules : Dict ModuleId (Set Triple)
    , diagrams : Dict DiagramId Diagram
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | UserSelectedDiagram DiagramId
    | UserUpdatedContent String
    | NoOpFrontendMsg
    | UserClickedSave
    | UserClickedModuleId ModuleId
    | Force3DMsg Force3DLayout.Msg
    | Tick Time.Posix


type ToBackend
    = NoOpToBackend
    | DiagramChangedAtFront Diagram -- leaves some room for optimisation!
    | AskForDiagramList
    | AskForDiagram DiagramId
    | SaveModule String (Set Triple)
    | RequestModule ModuleId
    | RequestModuleList


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected


type ToFrontend
    = NoOpToFrontend
    | DiagramList (List DiagramId)
    | DiagramContent Diagram -- sub-optimal, may want to know clientId to avoid feedback loop.
    | ModuleList (List ModuleId)
    | ModuleContent ModuleId (Set Triple)
