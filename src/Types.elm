module Types exposing (..)

import Browser exposing (UrlRequest)
import Browser.Navigation exposing (Key)
import Dict exposing (..)
import DomainModel exposing (..)
import File exposing (File)
import Force3DLayout
import LexerTypes exposing (..)
import Set exposing (..)
import Time exposing (Posix)
import Url exposing (Url)


type alias FrontendModel =
    { key : Key
    , time : Time.Posix
    , message : String
    , moduleList : List ModuleId -- ditto
    , editingModule : Maybe Module -- being edited.
    , effectiveModule : Module -- what is seen on the graph view
    , contentEditArea : String -- place to enter and edit modules and diagrams
    , tokenizedInput : List Token -- live parsing and errors.
    , parseStatus : Result String (Set Triple)
    , visual3d : Force3DLayout.Model
    , selectedModules : Set ModuleId -- for UI enabling
    , loadedModules : Dict ModuleId (Set Triple) -- all selected triples live here.
    , standbyModules : Dict ModuleId (Set Triple) -- downloaded but de-selected.
    , showRawTriples : Bool
    , layoutList : List ModuleId -- a Layout essentially is a Module.
    , inspectedItem : Maybe NodeId -- (could be Node or Link, really)
    , activeView : Maybe View
    , selectedTypes : Set ClassId -- to be moved into View struct.
    }


type alias BackendModel =
    { message : String
    , modules : Dict ModuleId (Set Triple)
    , views : Dict ModuleId (Set Triple)
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | UserUpdatedContent String
    | NoOpFrontendMsg
    | UserClickedSave
    | UserClickedModuleId ModuleId
    | Force3DMsg Force3DLayout.Msg
    | Tick Time.Posix
    | UserClickedParse
    | UserTogglesModuleSelection ModuleId Bool
    | UserTogglesRawMode Bool
    | UserClickedDownload
    | UserClickedLoadFile
    | FileSelected File
    | FileLoaded String
    | UserTogglesTypeSelection ClassId Bool
    | UserClickedShowAllTypes
    | UserClickedHideAllTypes


type ToBackend
    = NoOpToBackend
    | SaveModule String (Set Triple)
    | RequestModule ModuleId
    | RequestModuleList


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected


type ToFrontend
    = NoOpToFrontend
    | ModuleList (List ModuleId)
    | ModuleContent ModuleId (Set Triple)
