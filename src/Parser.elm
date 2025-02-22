module Parser exposing (..)

import Char
import DomainModel exposing (..)
import Lexer exposing (tokenToString)
import LexerTypes exposing (..)
import Murmur3
import Set exposing (Set)
import Time



{-
   Starting over as our output is domain model not triples.
   Our grammar is still simple and allows TTL-like statements.

   document = sentence { . sentenceList } EOF
   sentence = subject phraseList .
   subject = node | link
   link = node -> node
   phraseList = relation objectList [ ; phraseList ]
   objectList = object [ , objectList ]

   Lexer handles character level stuff so we get a list of tokens.
   There are reserved words with important semantics.
   All statements (phrases) in a sentence apply to the subject of that sentence only.
   There can be multiple statements about a node subject.
   But each sentence with a link subject is distinct - the link has a unique internal identity.

   Module (object) - signifies that a document contains architecture content.
   Diagram (object) - signifies that a document contains layout and styles.
   'is' or 'a' (relation) - subject in an instance of type object.
   Type - subject designates an architecture domain type.
   Link - subject designates an architecture domain link type and can be used as a relation.
   -> - there is a relation between subject and object and will be defined via the phraseList.
   Style (object) - the subject is used to convey style information, in a Diagram usually.
   colour (red, orange, ..)
   shape  (cube, sphere, cylinder, cone, ..)
   direction (N,S,E,W,U,D)
   label (relation)
   style (binding) - <style> apply <link type>. or <link type> apply <style>. ?
-}
{-
   Parser options. Recursive descent or state machine. Latter more flexible.
   Am I building the Module state here, or something preliminary?
   That is, I probably need to do spmoe more semantics using reserved words,
   looking at types and stuff.
   Previously I returned Triples and that actually was not a bad idea, as they're fairly
   easy to scan for types etc. Avoids ordering dependencies, allows for implied types.
   Difference here is uniqueness of each link sentence.

   We essentially fold the parse state over the token list.
   May be easier to have a long-hand fold, to make pattern matching explicit.
   Need parse state with partial parse, and collect the output (triples).
-}


type ParseState
    = AwaitingSubject (Set Triple)
    | WithSubject String (Set Triple)
    | WithPredicate String String (Set Triple)
    | TripleFound String String (Set Triple)
    | LinkAwaitingEndpoint String (Set Triple)
    | LinkWithEndpoint String String (Set Triple)
      --| LinkWithRelation String String String (Set Triple)
    | LinkComplete String String String (Set Triple)
    | ParseDone (Set Triple)
    | Error ParseError


type ParseError
    = SubjectExpected Token
    | PredicateExpected String Token
    | ObjectExpected String String Token
    | PunctuationExpected String String Token


parseTokensToTriples : Time.Posix -> List Token -> Result String (Set Triple)
parseTokensToTriples time input =
    -- time is used to distinguish between multiple links between a node pair.
    case asTriples input time of
        Ok triples ->
            Ok triples

        Err error ->
            Err <| parseErrorToString error


parseErrorToString : ParseError -> String
parseErrorToString err =
    case err of
        SubjectExpected token ->
            "I was expecting a subject but found " ++ tokenToString token

        PredicateExpected subject token ->
            "I was expecting a relation after " ++ subject ++ " but found " ++ tokenToString token

        ObjectExpected subject predicate token ->
            "I was expecting an object for "
                ++ subject
                ++ " "
                ++ predicate
                ++ " but found "
                ++ tokenToString token

        PunctuationExpected subject predicate token ->
            "I was expecting punctuation for "
                ++ subject
                ++ " "
                ++ predicate
                ++ " but found "
                ++ tokenToString token


asTriples : List Token -> Time.Posix -> Result ParseError (Set Triple)
asTriples tokens time =
    --TODO: Stop on error. Probably a List.Extra function!
    --https://package.elm-lang.org/packages/elm-community/list-extra/latest/List-Extra#stoppableFoldl
    case List.foldl (convertToTriples time) (AwaitingSubject Set.empty) tokens of
        AwaitingSubject triples ->
            Ok triples

        WithSubject subject triples ->
            --TODO: Is really an error state.
            Ok triples

        LinkAwaitingEndpoint subject triples ->
            Ok triples

        LinkWithEndpoint fromNode toNode triples ->
            Ok triples

        LinkComplete fromNode toNode relation triples ->
            Ok triples

        WithPredicate subject predicate triples ->
            --TODO: Is really an error state.
            Ok triples

        TripleFound subject predicate triples ->
            Ok triples

        ParseDone triples ->
            Ok triples

        Error parseError ->
            Err parseError


convertToTriples : Time.Posix -> Token -> ParseState -> ParseState
convertToTriples time token state =
    case state of
        AwaitingSubject triples ->
            case token of
                Name subject ->
                    WithSubject subject triples

                Fullstop ->
                    ParseDone triples

                _ ->
                    Error <| SubjectExpected token

        WithSubject subject triples ->
            case token of
                Name "->" ->
                    -- Special case creates anonymous node.
                    LinkAwaitingEndpoint subject triples

                Name predicate ->
                    WithPredicate subject predicate triples

                _ ->
                    Error <| PredicateExpected subject token

        LinkAwaitingEndpoint fromNode triples ->
            -- We have seen "->" and should see the second node.
            -- Make new anonymous node.
            -- Reify with the supplied from and to nodes.
            -- Remaining phrases apply to the anon node.
            -- TODO: Actually need to defer the reification until we have the whole phrase!
            case token of
                Name toNode ->
                    LinkWithEndpoint fromNode toNode triples

                Fullstop ->
                    ParseDone triples

                _ ->
                    Error <| SubjectExpected token

        LinkWithEndpoint fromNode toNode triples ->
            case token of
                Name relation ->
                    LinkComplete fromNode toNode relation triples

                Fullstop ->
                    ParseDone triples

                _ ->
                    Error <| SubjectExpected token

        LinkComplete fromNode toNode relation triplesOut ->
            -- We have all the components for a reified anonymous link node.
            -- We emit the necessary triples then allow the parse to continue as if
            -- the user had typed in the "anonymous" node!
            let
                reifyWithTarget : String -> ParseState
                reifyWithTarget withTarget =
                    -- Can use this for named nodes and quoted values, is the plan.
                    let
                        anonymousNode =
                            makeAnonNode time fromNode toNode

                        fromTriple =
                            ( anonymousNode, "_FROM", fromNode )

                        toTriple =
                            ( anonymousNode, "_TO", toNode )

                        baseTriple =
                            ( anonymousNode, relation, withTarget )

                        newTriples =
                            Set.fromList [ fromTriple, toTriple, baseTriple ]
                    in
                    TripleFound anonymousNode relation (Set.union newTriples triplesOut)
            in
            case token of
                Name object ->
                    reifyWithTarget object

                Quoted value ->
                    reifyWithTarget value

                _ ->
                    Error <| ObjectExpected toNode relation token

        WithPredicate subject predicate triples ->
            case token of
                Name object ->
                    let
                        newTriple =
                            ( subject, predicate, object )
                    in
                    TripleFound subject predicate (Set.insert newTriple triples)

                Quoted value ->
                    let
                        newTriple =
                            ( subject, predicate, value )
                    in
                    TripleFound subject predicate (Set.insert newTriple triples)

                _ ->
                    Error <| ObjectExpected subject predicate token

        TripleFound subject predicate triples ->
            case token of
                Name string ->
                    Error <| PunctuationExpected subject predicate token

                Comma ->
                    WithPredicate subject predicate triples

                Semicolon ->
                    WithSubject subject triples

                Fullstop ->
                    AwaitingSubject triples

                Quoted string ->
                    ParseDone triples

        --_ ->
        --    Error <| PunctuationExpected subject predicate token
        ParseDone triples ->
            state

        Error parseError ->
            --TODO: Abandon fold on error.
            state


makeAnonNode : Time.Posix -> String -> String -> String
makeAnonNode seed linkFrom linkTo =
    -- Two nodes separated by "->" designates an anonymous link, we must reify.
    -- If we see these nodes again, in another sentence, we make a distinct ID.
    "_" ++ String.fromInt (Murmur3.hashString (Time.posixToMillis seed) (linkFrom ++ linkTo))
