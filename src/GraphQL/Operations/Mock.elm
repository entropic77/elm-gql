module GraphQL.Operations.Mock exposing (Error(..), generate)

import GraphQL.Operations.CanonicalAST as Can
import GraphQL.Schema as Schema
import Json.Encode


type Error
    = Error


generate :
    Can.Document
    ->
        Result
            (List Error)
            (List { name : String, body : Json.Encode.Value })
generate doc =
    Ok (List.map definition doc.definitions)


definition : Can.Definition -> { name : String, body : Json.Encode.Value }
definition (Can.Operation def) =
    { name =
        Maybe.map Can.nameToString def.name
            |> Maybe.withDefault "query"
    , body =
        Json.Encode.object
            [ ( "data", mockDefinition def )
            ]
    }


mockDefinition : Can.OperationDetails -> Json.Encode.Value
mockDefinition def =
    Json.Encode.object
        (List.concatMap (encodeField Nothing) def.fields)


encodeField : Maybe String -> Can.Selection -> List ( String, Json.Encode.Value )
encodeField typename field =
    case field of
        Can.FieldObject details ->
            -- Note, still need to handle `details.wrapper`
            [ ( Can.getAliasedName field
              , Json.Encode.object
                    (List.concatMap (encodeField (Just details.object.name)) details.selection)
                    |> wrapEncoder details.wrapper
              )
            ]

        Can.FieldUnion details ->
            case onlyOneUnionCaseAndScalars (List.reverse details.selection) ( Nothing, [] ) of
                ( Just selectedVariant, otherFields ) ->
                    [ ( Can.getAliasedName field
                      , Json.Encode.object
                            (Can.UnionCase selectedVariant
                                :: otherFields
                                |> List.concatMap (encodeField (Just (Can.nameToString selectedVariant.tag)))
                            )
                            |> wrapEncoder details.wrapper
                      )
                    ]

                ( Nothing, _ ) ->
                    []

        Can.FieldScalar details ->
            case details.type_ of
                Schema.Scalar "typename" ->
                    case typename of
                        Nothing ->
                            [ ( Can.getAliasedName field
                              , Json.Encode.string "WRONG"
                              )
                            ]

                        Just nameStr ->
                            [ ( Can.getAliasedName field
                              , Json.Encode.string nameStr
                              )
                            ]

                _ ->
                    [ ( Can.getAliasedName field
                      , Schema.mockScalar details.type_
                      )
                    ]

        Can.FieldEnum details ->
            case details.values of
                [] ->
                    [ ( Can.getAliasedName field
                      , Json.Encode.null
                      )
                    ]

                top :: _ ->
                    [ ( Can.getAliasedName field
                      , Json.Encode.string top.name
                            |> wrapEncoder details.wrapper
                      )
                    ]

        Can.UnionCase details ->
            List.concatMap (encodeField typename) details.selection


wrapEncoder : Schema.Wrapped -> Json.Encode.Value -> Json.Encode.Value
wrapEncoder wrapped val =
    case wrapped of
        Schema.UnwrappedValue ->
            val

        Schema.InList inner ->
            Json.Encode.list identity [ wrapEncoder inner val ]

        Schema.InMaybe inner ->
            wrapEncoder inner val


onlyOneUnionCaseAndScalars : List Can.Selection -> ( Maybe Can.UnionCaseDetails, List Can.Selection ) -> ( Maybe Can.UnionCaseDetails, List Can.Selection )
onlyOneUnionCaseAndScalars sels (( maybeFoundUnion, otherFields ) as found) =
    case sels of
        [] ->
            found

        (Can.UnionCase union) :: remain ->
            if maybeFoundUnion /= Nothing then
                onlyOneUnionCaseAndScalars
                    remain
                    found

            else
                onlyOneUnionCaseAndScalars
                    remain
                    ( Just union, otherFields )

        (Can.FieldScalar scalar) :: remain ->
            onlyOneUnionCaseAndScalars
                remain
                ( maybeFoundUnion, Can.FieldScalar scalar :: otherFields )

        _ :: remain ->
            onlyOneUnionCaseAndScalars
                remain
                found
