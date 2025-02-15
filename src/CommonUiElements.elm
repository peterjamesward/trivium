module CommonUiElements exposing (..)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input


type RadioButtonPosition
    = First
    | Mid
    | Last
    | Top
    | Middle
    | Bottom


radioButton position label state =
    let
        borders =
            case position of
                First ->
                    { left = 2, right = 2, top = 2, bottom = 2 }

                Mid ->
                    { left = 0, right = 2, top = 2, bottom = 2 }

                Last ->
                    { left = 0, right = 2, top = 2, bottom = 2 }

                Top ->
                    { left = 2, right = 2, top = 2, bottom = 0 }

                Middle ->
                    { left = 2, right = 2, top = 0, bottom = 0 }

                Bottom ->
                    { left = 2, right = 2, top = 0, bottom = 2 }

        corners =
            case position of
                First ->
                    { topLeft = 6, bottomLeft = 6, topRight = 0, bottomRight = 0 }

                Mid ->
                    { topLeft = 0, bottomLeft = 0, topRight = 0, bottomRight = 0 }

                Last ->
                    { topLeft = 0, bottomLeft = 0, topRight = 6, bottomRight = 6 }

                Top ->
                    { topLeft = 6, bottomLeft = 0, topRight = 6, bottomRight = 0 }

                Middle ->
                    { topLeft = 0, bottomLeft = 0, topRight = 0, bottomRight = 0 }

                Bottom ->
                    { topLeft = 0, bottomLeft = 6, topRight = 0, bottomRight = 6 }
    in
    el
        [ padding 4
        , width fill
        , Border.roundEach corners
        , Border.widthEach borders
        , Border.color colorScheme.blue
        , Background.color <|
            if state == Input.Selected then
                colorScheme.lightBlue

            else
                colorScheme.white
        ]
    <|
        el [ centerX, centerY ] (text label)


colorScheme =
    { blue = rgb255 0x72 0x9F 0xCF
    , darkCharcoal = rgb255 0x2E 0x34 0x36
    , lightBlue = rgb255 0xC5 0xE8 0xF7
    , lightGrey = rgb255 0xE0 0xE0 0xE0
    , white = rgb255 0xFF 0xFF 0xFF
    , goldenYellow = rgb255 255 223 0
    , mikadoYellow = rgb255 255 196 12
    }


columnStyles =
    [ width fill
    , spacing 5
    , Border.width 2
    , Border.rounded 6
    , Border.color colorScheme.lightBlue
    , Font.family
        [ Font.typeface "Open Sans"
        , Font.monospace
        ]
    ]


buttonStyles =
    [ padding 5
    , Border.rounded 5
    , Background.color colorScheme.lightBlue
    , Element.focused
        [ Background.color colorScheme.lightBlue ]
    , Font.size 12
    ]


highlightButtonStyles =
    [ padding 5
    , Border.rounded 5
    , Border.color colorScheme.goldenYellow
    , Border.width 2
    , Background.color colorScheme.lightBlue
    , Element.focused
        [ Background.color colorScheme.lightBlue ]
    ]


niceLabel label =
    case String.split "^^" label of
        [ untagged, tag ] ->
            row [ width fill, spacing 4 ]
                [ text <| String.dropLeft 1 <| String.dropRight 1 untagged
                , el [ alignRight, Font.size 10 ] (text tag)
                ]

        _ ->
            text label


simpleButton action label =
    Input.button
        buttonStyles
        { onPress = Just action
        , label = niceLabel label
        }


highlightedButton action label =
    Input.button
        highlightButtonStyles
        { onPress = Just action
        , label = text label
        }


deleteButton action =
    Input.button
        buttonStyles
        { onPress = Just action
        , label = text "✗"
        }


warningButton action label =
    Input.button
        [ padding 5
        , Border.rounded 5
        , Background.color colorScheme.mikadoYellow
        , Element.focused
            [ Background.color colorScheme.goldenYellow ]
        ]
        { onPress = Just action
        , label = text label
        }


disabledButton label =
    Input.button
        [ padding 5
        , Border.rounded 5
        , Background.color colorScheme.lightGrey
        , Element.focused
            [ Background.color colorScheme.lightGrey ]
        ]
        { onPress = Nothing
        , label = text label
        }
