module LexerTypes exposing (..)


type LexerState
    = LookingForTokenStart
    | ChompingToken (List Char)
    | ChompingString (List Char)
    | StringEscape (List Char)
    | ChompingTag (List Char)
    | OptionalTagAfterString (List Char)


type alias Lexing =
    { row : Int
    , col : Int
    , tokens : List Token
    , state : LexerState
    }


type LexerError
    = LexExpectedTag


type Token
    = Name String
    | Comma
    | Semicolon
    | Fullstop
    | Quoted String
