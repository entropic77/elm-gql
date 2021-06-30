module Generate.Objects exposing (generateFiles)

import Dict
import Elm
import Elm.Annotation
import Elm.Gen.GraphQL.Engine as Engine
import Elm.Gen.Json.Decode as Json
import Elm.Pattern
import Generate.Common as Common
import GraphQL.Schema
import GraphQL.Schema.Object
import GraphQL.Schema.Type exposing (Type(..))
import String.Extra as String
import Utils.String



--objectToModule : String -> GraphQL.Schema.Object.Object -> Elm.File


objectToModule namespace object =
    let
        fieldTypesAndImpls =
            object.fields
                --|> List.filter
                --    (\field ->
                --        --List.member field.name [ "name", "slug", "id", "viewUrl", "parent" ]
                --        List.member field.name [ "parent" ]
                --    )
                |> List.foldl
                    (\field accDecls ->
                        let
                            implemented =
                                implementField
                                    namespace
                                    object.name
                                    field.name
                                    field.type_
                                    UnwrappedValue
                        in
                        ( field.name, implemented.annotation, implemented.expression ) :: accDecls
                    )
                    []

        objectTypeAnnotation =
            fieldTypesAndImpls
                |> List.map
                    (\( name, typeAnnotation, _ ) ->
                        ( formatName name, typeAnnotation )
                    )
                |> Elm.Annotation.record

        objectImplementation =
            fieldTypesAndImpls
                |> List.map (\( name, _, expression ) -> ( formatName name, expression ))
                |> Elm.record

        objectDecl =
            Elm.declarationWith (String.decapitalize object.name) objectTypeAnnotation objectImplementation
    in
    --Elm.file (Elm.moduleName [ namespace, "Object", object.name ])
    --    ""
    --    [
    objectDecl



--|> Elm.expose
--]


formatName str =
    case str of
        "_" ->
            "underscore"

        _ ->
            str


type Wrapped
    = UnwrappedValue
    | InList Wrapped
    | InMaybe Wrapped


implementField :
    String
    -> String
    -> String
    -> Type
    -> Wrapped
    ->
        { expression : Elm.Expression
        , annotation : Elm.Annotation.Annotation
        }
implementField namespace objectName fieldName fieldType wrapped =
    case fieldType of
        GraphQL.Schema.Type.Nullable newType ->
            implementField namespace objectName fieldName newType (InMaybe wrapped)

        GraphQL.Schema.Type.List_ newType ->
            implementField namespace objectName fieldName newType (InList wrapped)

        GraphQL.Schema.Type.Scalar scalarName ->
            let
                signature =
                    fieldSignature namespace objectName wrapped fieldType
            in
            { expression =
                Engine.field
                    (Elm.string fieldName)
                    (decodeScalar scalarName wrapped)
            , annotation = signature.annotation
            }

        GraphQL.Schema.Type.Enum enumName ->
            let
                signature =
                    fieldSignature namespace objectName wrapped fieldType
            in
            { expression =
                Engine.field
                    (Elm.string fieldName)
                    (Elm.valueFrom (Elm.moduleName [ namespace, "Enum", enumName ]) "decoder"
                        |> decodeWrapper wrapped
                    )
            , annotation = signature.annotation
            }

        GraphQL.Schema.Type.Object nestedObjectName ->
            { expression =
                Elm.lambda "selection_"
                    (Common.selectionLocal namespace
                        nestedObjectName
                        (Elm.Annotation.var "data")
                    )
                    --(Engine.typeSelection.annotation
                    --    (Common.local namespace nestedObjectName)
                    --    (Elm.Annotation.var "data")
                    --)
                    (\sel ->
                        Engine.object
                            (Elm.string fieldName)
                            (wrapExpression wrapped sel)
                    )
            , annotation =
                Elm.Annotation.function
                    [ --Engine.typeSelection.annotation
                      --    (Common.local namespace nestedObjectName)
                      --    (Elm.Annotation.var "data")
                      Common.selectionLocal namespace
                        nestedObjectName
                        (Elm.Annotation.var "data")
                    ]
                    --(Engine.typeSelection.annotation
                    --    (Common.local namespace objectName)
                    --    (wrapAnnotation wrapped
                    --        (Elm.Annotation.var
                    --            "data"
                    --        )
                    --    )
                    --)
                    (Common.selectionLocal namespace
                        objectName
                        (wrapAnnotation wrapped (Elm.Annotation.var "data"))
                    )
            }

        GraphQL.Schema.Type.Interface interfaceName ->
            --let
            --    signature =
            --        fieldSignature namespace objectName fieldType
            --in
            --{ expression = Elm.string ("unimplemented: " ++ Debug.toString fieldType)
            --, annotation = signature.annotation
            --}
            { expression =
                Elm.lambda "selection_"
                    --(Engine.typeSelection.annotation
                    --    (Common.local namespace interfaceName)
                    --    (Elm.Annotation.var "data")
                    --)
                    (Common.selectionLocal namespace
                        interfaceName
                        (Elm.Annotation.var "data")
                    )
                    (\sel ->
                        Engine.object
                            (Elm.string fieldName)
                            (wrapExpression wrapped sel)
                    )
            , annotation =
                Elm.Annotation.function
                    [ --Engine.typeSelection.annotation
                      --    (Common.local namespace interfaceName)
                      --    (Elm.Annotation.var "data")
                      Common.selectionLocal namespace
                        interfaceName
                        (Elm.Annotation.var "data")
                    ]
                    --(Engine.typeSelection.annotation
                    --    (Common.local namespace objectName)
                    --    (wrapAnnotation wrapped
                    --        (Elm.Annotation.var
                    --            "data"
                    --        )
                    --    )
                    --)
                    (Common.selectionLocal namespace
                        objectName
                        (wrapAnnotation wrapped (Elm.Annotation.var "data"))
                    )
            }

        GraphQL.Schema.Type.InputObject inputName ->
            let
                signature =
                    fieldSignature namespace objectName wrapped fieldType
            in
            { expression = Elm.string ("unimplemented: " ++ Debug.toString fieldType)
            , annotation = signature.annotation
            }

        GraphQL.Schema.Type.Union unionName ->
            { expression =
                Elm.lambda "union_"
                    --(Engine.typeSelection.annotation
                    --    (Common.local namespace unionName)
                    --    (Elm.Annotation.var
                    --        "data"
                    --    )
                    --)
                    (Common.selectionLocal namespace
                        unionName
                        (Elm.Annotation.var "data")
                    )
                    (\un ->
                        Engine.object
                            (Elm.string fieldName)
                            (wrapExpression wrapped un)
                    )
            , annotation =
                Elm.Annotation.function
                    [ --Engine.typeSelection.annotation
                      --    (Common.local namespace unionName)
                      --    (Elm.Annotation.var
                      --        "data"
                      --    )
                      Common.selectionLocal namespace
                        unionName
                        (Elm.Annotation.var "data")
                    ]
                    --(Engine.typeSelection.annotation
                    --    (Common.local namespace objectName)
                    --    (wrapAnnotation wrapped
                    --        (Elm.Annotation.var
                    --            "data"
                    --        )
                    --    )
                    --)
                    (Common.selectionLocal namespace
                        objectName
                        (wrapAnnotation wrapped (Elm.Annotation.var "data"))
                    )
            }


wrapAnnotation : Wrapped -> Elm.Annotation.Annotation -> Elm.Annotation.Annotation
wrapAnnotation wrap signature =
    case wrap of
        UnwrappedValue ->
            signature

        InList inner ->
            Elm.Annotation.list (wrapAnnotation inner signature)

        InMaybe inner ->
            Elm.Annotation.maybe (wrapAnnotation inner signature)


wrapExpression : Wrapped -> Elm.Expression -> Elm.Expression
wrapExpression wrap exp =
    case wrap of
        UnwrappedValue ->
            exp

        InList inner ->
            Engine.list
                (wrapExpression inner exp)

        InMaybe inner ->
            Engine.nullable
                (wrapExpression inner exp)


fieldSignature :
    String
    -> String
    -> Wrapped
    -> Type
    ->
        { annotation : Elm.Annotation.Annotation
        }
fieldSignature namespace objectName wrapped fieldType =
    let
        dataType =
            Common.localAnnotation namespace fieldType Nothing
                |> wrapAnnotation wrapped

        typeAnnotation =
            Common.selectionLocal namespace
                objectName
                dataType
    in
    { annotation = typeAnnotation
    }


decodeScalar : String -> Wrapped -> Elm.Expression
decodeScalar scalarName wrapped =
    let
        lowered =
            String.toLower scalarName

        decoder =
            case lowered of
                "string" ->
                    Json.string

                "int" ->
                    Json.int

                "float" ->
                    Json.float

                "id" ->
                    Engine.decodeId

                "boolean" ->
                    Json.bool

                _ ->
                    Elm.valueFrom (Elm.moduleName [ "Scalar" ]) (Utils.String.formatValue scalarName)
                        |> Elm.get "decoder"
    in
    decodeWrapper wrapped decoder


decodeWrapper : Wrapped -> Elm.Expression -> Elm.Expression
decodeWrapper wrap exp =
    case wrap of
        UnwrappedValue ->
            exp

        InList inner ->
            Json.list
                (decodeWrapper inner exp)

        InMaybe inner ->
            Engine.decodeNullable
                (decodeWrapper inner exp)


generateFiles : String -> GraphQL.Schema.Schema -> List Elm.File
generateFiles namespace graphQLSchema =
    let
        objects =
            graphQLSchema.objects
                |> Dict.toList
                |> List.map Tuple.second

        interfaces =
            graphQLSchema.interfaces
                |> Dict.toList
                |> List.map Tuple.second

        renderedObjects =
            List.map (objectToModule namespace) objects
                ++ List.map (objectToModule namespace) interfaces

        phantomTypeDeclarations =
            objects
                |> List.map
                    .name

        unionTypeDeclarations =
            graphQLSchema.unions
                |> Dict.toList
                |> List.map
                    (Tuple.second >> .name)

        inputTypeDeclarations =
            graphQLSchema.inputObjects
                |> Dict.toList
                |> List.map
                    (Tuple.second >> .name)

        interfaceTypeDeclarations =
            graphQLSchema.interfaces
                |> Dict.toList
                |> List.map
                    (Tuple.second >> .name)

        names =
            phantomTypeDeclarations
                ++ unionTypeDeclarations
                ++ interfaceTypeDeclarations

        inputHelpers =
            List.concatMap
                (\name ->
                    [ Elm.aliasWith name
                        []
                        (Engine.typeArgument.annotation
                            (Elm.Annotation.named Elm.local (name ++ "_"))
                        )
                    , Elm.customType (name ++ "_") [ ( name, [] ) ]
                    ]
                )
                inputTypeDeclarations

        helpers =
            List.concatMap
                (\name ->
                    [ Elm.aliasWith name
                        [ "data" ]
                        (Engine.typeSelection.annotation
                            (Elm.Annotation.named Elm.local (name ++ "_"))
                            (Elm.Annotation.var "data")
                        )
                    , Elm.customType (name ++ "_") [ ( name, [] ) ]
                    ]
                )
                names

        engineAliases =
            [ Elm.declaration "select"
                (Elm.valueFrom
                    Engine.moduleName_
                    "select"
                )
            , Elm.declaration "with"
                (Elm.valueFrom
                    Engine.moduleName_
                    "with"
                )
            , Elm.declaration "map"
                (Elm.valueFrom
                    Engine.moduleName_
                    "map"
                )
            , Elm.declaration "map2"
                (Elm.valueFrom
                    Engine.moduleName_
                    "map2"
                )
            , Elm.declaration "recover"
                (Elm.valueFrom
                    Engine.moduleName_
                    "recover"
                )
            , Elm.aliasWith "Selection"
                [ "source"
                , "data"
                ]
                (Engine.typeSelection.annotation
                    (Elm.Annotation.var "source")
                    (Elm.Annotation.var "data")
                )
            , Elm.aliasWith "Id"
                []
                (Elm.Annotation.named Engine.moduleName_ "Id")
            , Elm.aliasWith "Query"
                [ "data" ]
                (Engine.typeSelection.annotation
                    Engine.typeQuery.annotation
                    (Elm.Annotation.var "data")
                )
            , Elm.declaration "query"
                (Elm.valueFrom
                    Engine.moduleName_
                    "query"
                )
            , Elm.aliasWith "Mutation"
                [ "data" ]
                (Engine.typeSelection.annotation
                    Engine.typeMutation.annotation
                    (Elm.Annotation.var "data")
                )
            , Elm.declaration "mutation"
                (Elm.valueFrom
                    Engine.moduleName_
                    "mutation"
                )
            ]

        masterObjectFile =
            Elm.file (Elm.moduleName [ namespace ])
                ""
                (engineAliases
                    ++ renderedObjects
                    ++ helpers
                    ++ inputHelpers
                )
    in
    [ masterObjectFile ]



--:: objectFiles
