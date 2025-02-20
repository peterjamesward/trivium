module Parser exposing (..)

import Char
import DomainModel exposing (..)
import LexerTypes exposing (..)
import Set exposing (Set)



{-
   Starting over as our output is domain model not triples.
   Our grammar is still simple and allows TTL-like statements.

   document = [sentence] <EOF>
   sentence = subject phraseList .
   phraseList = relation objectList [ ; phraseList ]
   objectList = object [ , objectList ]

   Lexer handles character level stuff so we get a list of tokens.
   There are reserved words with important semantics.

   Module (object) - signifies that a document contains architecture content.
   Diagram (object) - signifies that a document contains layout and styles.
   'is' or 'a' (relation) - subject in an instance of type object.
   Type - subject designates a domain type.
   Link - subject designates a domain link type and can be used as a relation.
   -> - there is a relation between subject and object and will be defined via the phraseList.
   Style (object) - the subject is used to convey style information, in a Diagram usually.
   colour (red, orange, ..)
   shape  (cube, sphere, cylinder, cone, ..)
   direction (N,S,E,W,U,D)
   label (relation)
   style (binding) - <style> appliesTo <link type> or <link type> adopts <style> ?
-}


type ParseResult
    = ParsedModule Module
    | ParsedDiagram Diagram
    | ParseError


parse : List Token -> ParseResult
parse tokens =
    ParseError
