module Lexer exposing (..)

import LexerTypes exposing (..)
import Set



{-
   I prefer to seperate the lexical analysis from the full parse. ymmv.
   Everything else is a token.
   Indentation is not significant.

   this a Class;
       with anAttribute;
       butAlso this, that, """look out below""".

   a -> b a Dataflow;
       carries someData;
       protocol SNA.

   Obviously the "a -> b" bit is tricky but not very.
   Quite a few reserved words; the parser deals with those.

   Also: attach row and column info to every token.
-}


tokenToString : Token -> String
tokenToString token =
    case token of
        Name object ->
            object

        Comma ->
            ","

        Semicolon ->
            ";"

        Fullstop ->
            "."

        Quoted string ->
            "\"" ++ string ++ "\""


tokenize : String -> List Token
tokenize input =
    -- TODO: return errors
    -- https://package.elm-lang.org/packages/elm-community/list-extra/latest/List-Extra#stoppableFoldl
    let
        lexing =
            { row = 1, col = 1, tokens = [], state = LookingForTokenStart }

        finalState =
            List.foldl nextCharacter lexing (String.toList input)
    in
    List.reverse finalState.tokens


whitespace =
    Set.fromList [ ' ', '\n', '\u{000D}', '\t' ]


punctuation =
    Set.fromList [ ',', ';', '.', ':' ]


tokenTerminators =
    Set.union whitespace punctuation


tokenFromPunctuation punc =
    case punc of
        '.' ->
            Fullstop

        ',' ->
            Comma

        ';' ->
            Semicolon

        ':' ->
            Name "label"

        _ ->
            Fullstop


nextCharacter : Char -> Lexing -> Lexing
nextCharacter char lex =
    let
        nextLex =
            if char == '\n' then
                { lex | row = lex.row + 1, col = 1 }

            else
                { lex | col = lex.col + 1 }
    in
    case lex.state of
        LookingForTokenStart ->
            -- Skip until we find something that can start a token: name or string.
            -- The '-' case is only to detect link arrows.
            if Char.isAlphaNum char || (char == '_') || (char == '-') then
                { nextLex | state = ChompingToken [ char ] }

            else if char == '"' then
                { nextLex | state = ChompingString [ char ] }

            else if Set.member char punctuation then
                { nextLex
                    | state = LookingForTokenStart
                    , tokens = tokenFromPunctuation char :: lex.tokens
                }

            else
                nextLex

        ChompingToken reversed ->
            -- Consume input until it ends a token, then save the token.
            if Set.member char whitespace then
                let
                    newToken =
                        Name <| String.fromList <| List.reverse reversed
                in
                { nextLex
                    | state = LookingForTokenStart
                    , tokens = newToken :: nextLex.tokens
                }

            else if Set.member char punctuation then
                let
                    newToken =
                        Name <| String.fromList <| List.reverse reversed
                in
                { nextLex
                    | state = LookingForTokenStart
                    , tokens = tokenFromPunctuation char :: newToken :: nextLex.tokens
                }

            else
                { nextLex | state = ChompingToken <| char :: reversed }

        ChompingString reversed ->
            -- Consume input until unescaped double quote.
            if char == '"' then
                let
                    newToken =
                        Quoted <| (String.fromList <| List.reverse <| char :: reversed)
                in
                --nextCharacter
                --    char
                { lex
                    | state = LookingForTokenStart
                    , tokens = newToken :: lex.tokens
                }

            else if char == '\\' then
                { nextLex | state = StringEscape reversed }

            else
                { nextLex | state = ChompingString <| char :: reversed }

        StringEscape reversed ->
            { nextLex | state = ChompingString <| char :: '\\' :: reversed }
