module Utils.String exposing (formatScalar, formatTypename, formatValue)

import String


formatTypename : String -> String
formatTypename introName =
    let
        ( leadingUnderscores, name ) =
            getLeadingUnderscores introName

        first =
            String.left 1 name
    in
    String.toUpper first ++ String.dropLeft 1 name ++ leadingUnderscores


{-| Converts a string from the gql to a string format that is amenable to Elm's typesystem.

Generally this means:
1st letter is capitalized
Subsequent letters are capitalized if there is a lowercase letter between it and the first letter.

Sounds weird, but it's the standard for Elm.

Por ejemplo:

    URL -> Url
    ViewID -> ViewId

-}
formatScalar : String -> String
formatScalar introName =
    let
        ( leadingUnderscores, name ) =
            getLeadingUnderscores introName

        first =
            String.left 1 name

        remaining =
            String.dropLeft 1 name

        body =
            String.foldl
                elmify
                ( False, "" )
                remaining
                |> Tuple.second
    in
    String.toUpper first ++ body ++ leadingUnderscores


{-| Same logic as above, but the first letter is lowercase
-}
formatValue : String -> String
formatValue introName =
    let
        ( leadingUnderscores, name ) =
            getLeadingUnderscores introName

        first =
            String.left 1 name

        remaining =
            String.dropLeft 1 name

        body =
            String.foldl
                elmify
                ( False, "" )
                remaining
                |> Tuple.second
    in
    String.toLower first
        ++ body
        ++ leadingUnderscores
        |> sanitize


getLeadingUnderscores : String -> ( String, String )
getLeadingUnderscores string =
    getLeadingUnderscoresHelper "" string


getLeadingUnderscoresHelper : String -> String -> ( String, String )
getLeadingUnderscoresHelper leading string =
    case String.uncons string of
        Nothing ->
            ( leading, string )

        Just ( '_', tail ) ->
            getLeadingUnderscoresHelper (String.cons '_' leading)
                tail

        Just _ ->
            ( "", string )


elmify : Char -> ( Bool, String ) -> ( Bool, String )
elmify char ( passedLower, gathered ) =
    if Char.isUpper char && passedLower then
        ( passedLower
        , gathered
            ++ String.fromChar char
        )

    else
        ( Char.isLower char || passedLower
        , gathered
            ++ String.toLower
                (String.fromChar char)
        )


{-| Note, this should be done in elm-prefab directly!
-}
sanitize : String -> String
sanitize name =
    case name of
        "in" ->
            "in_"

        "type" ->
            "type_"

        "case" ->
            "case_"

        "let" ->
            "let_"

        "module" ->
            "module_"

        "exposing" ->
            "exposing_"

        _ ->
            name
