module DiagramToD2 exposing (..)

import Dict exposing (..)
import DomainModel exposing (..)
import Set exposing (..)


diagramToD2 : D2Diagram -> String
diagramToD2 diagram =
    -- { id = DiagramId
    -- , classes = Dict ClassId D2Class
    -- , nodes = Dict NodeId D2Node
    -- , links = Dict ( NodeId, NodeId ) D2Link
    -- }
    let
        withWrapper id label contents =
            id ++ " : " ++ label ++ " {\n" ++ contents ++ "\n}\n"

        classes =
            withWrapper "classes"
                ""
                (String.concat <| List.map writeClass <| Dict.values diagram.classes)

        nodes : String
        nodes =
            diagram.nodes
                |> Dict.values
                |> List.map writeNode
                |> String.concat

        links : String
        links =
            diagram.links
                |> Dict.values
                |> List.map writeLink
                |> String.concat

        writeClass : D2Class -> String
        writeClass class =
            withWrapper class.id "" <|
                withWrapper "style" "" <|
                    writeAttributes class.attributes

        writeNode : D2Node -> String
        writeNode node =
            withWrapper node.id node.label <|
                case node.class of
                    Just class ->
                        "class:" ++ class

                    Nothing ->
                        ""

        writeLink : D2Link -> String
        writeLink link =
            withWrapper (link.fromNode ++ " -> " ++ link.toNode) link.label <|
                writeAttributes link.attributes

        writeAttributes : Dict String String -> String
        writeAttributes dict =
            dict
                |> Dict.toList
                |> List.map (\( key, value ) -> key ++ ": " ++ value)
                |> String.join "\n"
    in
    String.join "" <| [ classes, nodes, links ]



{- SAMPLE
   direction: right
   classes: {
     load balancer: {
       label: load\nbalancer
       width: 100
       height: 200
       style: {
         stroke-width: 0
         fill: "#44C7B1"
         shadow: true
         border-radius: 5
       }
     }
     unhealthy: {
       style: {
         fill: "#FE7070"
         stroke: "#F69E03"
       }
     }
   }

   web traffic -> web lb
   web lb.class: load balancer

   web lb -> api1
   web lb -> api2
   web lb -> api3

   api2.class: unhealthy

   api1 -> cache lb
   api3 -> cache lb

   cache lb.class: load balancer
-}
