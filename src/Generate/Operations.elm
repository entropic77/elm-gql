module Generate.Operations exposing (generateFiles)

import Dict
import Elm
import Generate.Args
import Generate.Input as Input
import Generate.Input.Encode
import GraphQL.Schema exposing (Namespace)
import Utils.String


queryToModule :
    Namespace
    -> Input.Operation
    -> GraphQL.Schema.Schema
    -> GraphQL.Schema.Field
    -> Elm.File
queryToModule namespace op schema operation =
    let
        dir =
            directory op

        input =
            case operation.arguments of
                [] ->
                    []

                _ ->
                    List.concat
                        [ [ Elm.comment """  Inputs """
                          , Generate.Input.Encode.toRecordInput namespace
                                schema
                                operation.arguments
                          ]
                        , Generate.Input.Encode.toRecordOptionals namespace
                            schema
                            operation.arguments
                        , Generate.Input.Encode.toRecordNulls operation.arguments
                        , [ Generate.Input.Encode.toInputRecordAlias namespace schema "Input" operation.arguments
                          ]
                        ]

        queryFunction =
            Generate.Args.createBuilder namespace
                schema
                operation.name
                operation.arguments
                operation.type_
                op

        -- example =
        --     Generate.Example.example namespace
        --         schema
        --         operation.name
        --         operation.arguments
        --         operation.type_
        --         op
        -- optionalHelpers =
        --     if List.any Input.isOptional operation.arguments then
        --         let
        --             topLevelAlias =
        --                 Elm.alias "Optional"
        --                     (Engine.types_.optional
        --                         (Elm.Annotation.named [ namespace.namespace ]
        --                             (case op of
        --                                 Input.Query ->
        --                                     operation.name ++ "_Option"
        --                                 Input.Mutation ->
        --                                     operation.name ++ "_MutOption"
        --                             )
        --                         )
        --                     )
        --                     |> Elm.expose
        --             optional =
        --                 List.filter Input.isOptional operation.arguments
        --         in
        --         topLevelAlias
        --             :: Generate.Args.optionsRecursive namespace
        --                 schema
        --                 operation.name
        --                 optional
        --             ++ [ Generate.Args.nullsRecord namespace operation.name optional
        --                     |> Elm.declaration "null"
        --                     |> Elm.expose
        --                ]
        --     else
        --         []
    in
    Elm.fileWith
        [ namespace.namespace
        , dir
        , Utils.String.formatTypename operation.name
        ]
        { docs =
            \_ -> []

        -- "\n\nExample usage:\n\n"
        --     -- ++ Elm.expressionImports example
        --     ++ "\n\n\n"
        -- ++ Elm.toString example
        , aliases = []
        }
        (input ++ [ queryFunction ]
         -- :: optionalHelpers
        )


directory : Input.Operation -> String
directory op =
    case op of
        Input.Query ->
            "Queries"

        Input.Mutation ->
            "Mutations"


generateFiles : Namespace -> Input.Operation -> GraphQL.Schema.Schema -> List Elm.File
generateFiles namespace op schema =
    case op of
        Input.Mutation ->
            schema.mutations
                |> Dict.toList
                |> List.map
                    (\( _, oper ) ->
                        queryToModule namespace op schema oper
                    )

        Input.Query ->
            schema.queries
                |> Dict.toList
                |> List.map
                    (\( _, oper ) ->
                        queryToModule namespace op schema oper
                    )


{--}
