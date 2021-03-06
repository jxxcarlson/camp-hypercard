module L0.L0 exposing (Format, view)

import CellParserExcel
import Dict exposing (Dict)
import Element exposing (..)
import Element.Font as Font
import Html.Attributes
import L0.ASTTools
import L0.MExpression exposing (MExpression(..))
import L0.Utility as Utility
import L0.Widget as Widget
import Maybe.Extra
import Spreadsheet


type alias Format =
    -- Units = pixels
    { lineWidth : Int, leftPadding : Int, bottomPadding : Int, topPadding : Int }


view : Format -> MExpression -> Element msg
view format mexpr =
    let
        _ =
            Debug.log "view, mexpr" mexpr
    in
    case mexpr of
        Literal str ->
            text str

        Verbatim char str ->
            case char of
                '`' ->
                    viewInlineCode str

                '$' ->
                    unimplemented "Unimplemented: math" str

                _ ->
                    unimplemented "Unimplemented verbatim option" str

        MElement fname mexpr2 ->
            viewElement format fname mexpr2

        MList list_ ->
            paragraph [ width fill ] (List.map (view format) list_)

        MProblem problem ->
            text ("Problem: " ++ problem)


viewInlineCode str =
    el [ Font.family [ Font.typeface "Courier", Font.monospace ], Font.color verbatimColor ] (Element.text str)


unimplemented message content =
    el [ Font.size 14, Font.color (Element.rgb255 240 200 200) ] (text <| message ++ ": " ++ content)


pe =
    paddingEach { top = 0, bottom = 12, left = 0, right = 0 }


viewElement : Format -> String -> MExpression -> Element msg
viewElement format fname mexpr =
    case Dict.get fname fDict of
        Nothing ->
            text <| "Function " ++ fname ++ " not found, args " ++ Debug.toString mexpr

        Just f ->
            f format mexpr


fDict : Dict String (Format -> MExpression -> Element msg)
fDict =
    Dict.fromList
        [ ( "i", \format expr -> wrappedRow [ width fill, Font.italic ] [ view format expr ] )
        , ( "b", \format expr -> wrappedRow [ width fill, Font.bold ] [ view format expr ] )
        , ( "red", \format expr -> wrappedRow [ width fill, Font.color (rgb255 190 0 0) ] [ view format expr ] )
        , ( "blue", \format expr -> wrappedRow [ width fill, Font.color (rgb255 0 0 200) ] [ view format expr ] )
        , ( "image", \format expr -> image format expr )
        , ( "heading1", \format expr -> heading1 format expr )
        , ( "heading2", \format expr -> heading2 format expr )
        , ( "heading3", \format expr -> heading3 format expr )
        , ( "quote", \format expr -> quote format expr )
        , ( "link", \format expr -> link format expr )
        , ( "item", \format expr -> item format expr )

        --, ( "sum", \format args expr -> Widget.sum args expr )
        , ( "preformatted", \format expr -> preformatted format expr )
        , ( "indent", \format expr -> indent format expr )

        --, ( "bargraph", \format args expr -> Widget.bargraph args expr )
        --, ( "spreadsheet", \format args expr -> spreadsheet format args expr )
        --, ( "row", \format args expr -> Element.none )
        --, ( "list", \format args expr -> list format args expr )
        ]


item format expr =
    let
        itemPadding = Element.paddingEach {top = 8, bottom = 8, left =24, right = 0}
    in
    Element.wrappedRow [itemPadding, width (px format.lineWidth), Element.centerY] [el [Font.size 18] (text "???"), view format expr]

quote format expr =
    case expr of
        MList [ Literal str ] ->
            el [] (Element.text <| "\"" ++ String.trim str ++ "\"")

        _ ->
            unimplemented "Bad data: " "quote"


link format expr =
    case (L0.ASTTools.normalize expr)  of
        MList [ Literal str ] ->
            case String.words str of
                [ label, url ] ->
                    newTabLink []
                        { url = url
                        , label = el [ linkColor ] (text label)
                        }

                [ url ] ->
                    newTabLink []
                        { url = url
                        , label = el [ linkColor ] (text url)
                        }


                _ ->
                    Element.el [ Font.size 32, verticalPadding 32 8 ] (Element.text "Bad data for link")

        MList [ Literal label, Literal url] ->
            newTabLink []
                { url = url
                , label = el [ linkColor ] (text label)
                }
        _ ->
            Element.el [ Font.size 32, verticalPadding 32 8 ] (Element.text "Bad data for link")


heading1 format expr =
    case expr of
        MList [ Literal str ] ->
            Element.el [ Font.size 32, verticalPadding 32 8 ] (Element.text str)

        _ ->
            Element.el [ Font.size 32, verticalPadding 32 8 ] (Element.text "Bad data for heading")


heading2 format expr =
    case expr of
        MList [ Literal str ] ->
            Element.el [ Font.size 24, verticalPadding 24 8 ] (Element.text str)

        _ ->
            Element.el [ Font.size 24, verticalPadding 24 8 ] (Element.text "Bad data for heading")


heading3 format expr =
    case expr of
        MList [ Literal str ] ->
            Element.el [ Font.size 18, verticalPadding 18 8 ] (Element.text str)

        _ ->
            Element.el [ Font.size 18, verticalPadding 18 8 ] (Element.text "Bad data for heading")


verticalPadding top bottom =
    Element.paddingEach { left = 0, right = 0, top = top, bottom = bottom }


image format expr_ =
    let
        w =
            500

        expr =
            Debug.log "EXPR" (L0.ASTTools.normalize expr_)
    in
    case expr of
        MList [ opts_, Literal url_ ] ->
            column [ spacing 8, Element.width (px w) ]
                [ Element.image [ Element.width (px w) ]
                    { src = url_, description = "image" }
                ]

        MList [ Literal url_ ] ->
            column [ spacing 8, Element.width (px w) ]
                [ Element.image [ Element.width (px w) ]
                    { src = url_, description = "image" }
                ]

        _ ->
            Element.el [ Font.size 14 ] (Element.text "Error: bad data for image")



--list format args_ body =
--    let
--        dict =
--            Utility.keyValueDict args_
--    in
--    case body of
--        MList list_ ->
--            column [ spacing 4, listPadding ]
--                (elementTitle args_ :: List.indexedMap (\k item_ -> renderListItem (getPrefixSymbol k dict) format item_) (filterOutBlankItems list_))
--
--        _ ->
--            el [ Font.color redColor ] (text "Malformed list")


filterOutBlankItems : List MExpression -> List MExpression
filterOutBlankItems list_ =
    List.filter (\item_ -> not (isBlankItem item_)) list_


isBlankItem : MExpression -> Bool
isBlankItem el =
    case el of
        Literal str ->
            String.trim str == ""

        _ ->
            False


getPrefixSymbol k dict =
    case Dict.get "s" dict of
        Just "numbered" ->
            el [ Font.size 12, alignTop, moveDown 2.2 ] (text (String.fromInt (k + 1) ++ "."))

        Nothing ->
            el [ Font.size 16 ] (text "???")

        Just "bullet" ->
            el [ Font.size 16 ] (text "???")

        Just "none" ->
            Element.none

        Just str ->
            el [ Font.size 16 ] (text str)



--renderListItem prefixSymbol renderArgs elt =
--    case elt of
--        MElement "item" body ->
--            row [ spacing 8 ] [ el [ alignTop, moveDown 2 ] prefixSymbol, view renderArgs elt ]
--
--        MElement "list" body ->
--            case body of
--                MList list_ ->
--                    column [ spacing 4, listPadding ] (elementTitle args :: List.indexedMap (\k item_ -> renderListItem (getPrefixSymbol k dict) renderArgs item_) (filterOutBlankItems list_))
--
--                _ ->
--                    el [ Font.color redColor ] (text "Malformed list")
--
--        _ ->
--            Element.none


redColor =
    rgb 0.7 0 0


elementTitle args_ =
    let
        dict =
            Utility.keyValueDict args_

        title =
            Dict.get "title" dict
    in
    case title of
        Nothing ->
            Element.none

        Just title_ ->
            el [ Font.size titleSize ] (text title_)


titleSize =
    14


listPadding =
    paddingEach { left = 18, right = 0, top = 8, bottom = 0 }


spreadsheet format args body =
    let
        spreadsheet1 =
            getCSV body
                |> Spreadsheet.readFromList CellParserExcel.parse
                |> Spreadsheet.eval

        spreadsheet2 : List (List String)
        spreadsheet2 =
            Spreadsheet.printAsList spreadsheet1

        renderItem str =
            el [ width (px 60) ] (el [ alignRight ] (text str))

        renderRow items =
            row [ spacing 10 ] (List.map renderItem items)
    in
    column [ spacing 8, indentPadding ] (List.map renderRow spreadsheet2)


getCSV : MExpression -> List (List String)
getCSV element =
    case element of
        MList list_ ->
            case List.map extractText list_ of
                data ->
                    data
                        |> Maybe.Extra.values
                        |> String.join ""
                        |> String.split ";;"
                        |> List.filter (\line -> line /= "")
                        |> List.map (String.split ";")
                        |> List.map (List.map String.trim)

        _ ->
            [ [] ]


extractText : MExpression -> Maybe String
extractText element =
    case element of
        Literal content ->
            Just content

        _ ->
            Nothing


indentPadding =
    paddingEach { left = 24, right = 0, top = 0, bottom = 0 }



--getRows_ body =
--    case body of
--        MList list_ ->
--            List.map getRow list_
--                |> List.filter (\s -> s /= "")
--                |> List.map (String.split ",")
--                |> List.map (List.map String.trim)
--
--        _ ->
--            [ [] ]
--
--getRow element =
--    case element of
--        MElement "row" [] (MList [ Literal t ]) ->
--            t
--
--        _ ->
--            ""


indent : Format -> MExpression -> Element msg
indent format expr =
    column [ paddingEach { left = 18, right = 0, top = 0, bottom = 0 } ] [ view format expr ]


preformatted : Format -> MExpression -> Element msg
preformatted format expr =
    el
        [ Font.family
            [ Font.typeface "Courier"
            , Font.monospace
            ]
        , Font.color verbatimColor
        , moveLeft 14
        , verticalPadding 0 15
        ]
        (text (Utility.extractText expr |> Maybe.withDefault "(no text)" |> String.dropLeft 3 |> (\x -> "    " ++ x)))


verbatimColor =
    rgb255 150 0 220


unquote : String -> String
unquote str =
    String.replace "\"" "" str


linkColor =
    Font.color (Element.rgb255 0 0 245)


image1 : Format -> List String -> MExpression -> Element msg
image1 format args body =
    let
        dict =
            Utility.keyValueDict args

        description =
            Dict.get "caption" dict |> Maybe.withDefault ""

        caption =
            case Dict.get "caption" dict of
                Nothing ->
                    none

                Just c ->
                    row [ placement, Element.width fill ] [ el [ Element.width fill ] (text c) ]

        width =
            case Dict.get "width" dict of
                Nothing ->
                    px displayWidth

                Just w_ ->
                    case String.toInt w_ of
                        Nothing ->
                            px displayWidth

                        Just w ->
                            px w

        placement =
            case Dict.get "placement" dict of
                Nothing ->
                    centerX

                Just "left" ->
                    alignLeft

                Just "right" ->
                    alignRight

                Just "center" ->
                    centerX

                _ ->
                    centerX

        displayWidth =
            format.lineWidth
    in
    column [ spacing 8, Element.width (px displayWidth), placement ]
        [ Element.image [ Element.width width, placement ]
            { src = getText body |> Maybe.withDefault "no image url" |> unquote, description = description }
        , caption
        ]


htmlAttribute : String -> String -> Element.Attribute msg
htmlAttribute key value =
    Element.htmlAttribute (Html.Attributes.attribute key value)


getText : MExpression -> Maybe String
getText mexpr =
    case mexpr of
        Literal s ->
            Just (String.trim s)

        MList list_ ->
            List.map getText list_ |> Maybe.Extra.values |> String.join " " |> String.trim |> Just

        _ ->
            Nothing
