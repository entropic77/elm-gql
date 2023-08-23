module GraphQL.Operations.Generate.Mock.Fragment exposing (generate)

{-| -}

import Elm
import Elm.Annotation as Type
import Generate.Path
import GraphQL.Operations.CanonicalAST as Can
import GraphQL.Operations.Generate.Decode exposing (Namespace)
import GraphQL.Operations.Generate.Help as Help
import GraphQL.Operations.Generate.Mock.Value as Mock
import GraphQL.Schema
import Utils.String


generate :
    { namespace : Namespace
    , schema : GraphQL.Schema.Schema
    , document : Can.Document

    -- all the dirs between CWD and the GQL file
    , path : String

    -- all the directories between the Elm source folder and the GQL file
    , gqlDir : List String
    , generateMocks : Bool
    }
    -> Can.Fragment
    -> Elm.File
generate { namespace, schema, document, path, gqlDir } frag =
    let
        paths =
            if frag.isGlobal then
                Generate.Path.fragmentGlobal
                    { name = Utils.String.formatTypename (Can.nameToString frag.name)
                    , namespace = namespace.namespace
                    , path = path
                    , gqlDir = gqlDir
                    }

            else
                Generate.Path.fragment
                    { name = Utils.String.formatTypename (Can.nameToString frag.name)
                    , path = path
                    , gqlDir = gqlDir
                    }
    in
    Elm.fileWith paths.mockModulePath
        { aliases = [ ( paths.modulePath, "Fragment" ) ]
        , docs =
            \docs ->
                [ "This is a **mock** module for the `" ++ Can.nameToString frag.name ++ "` fragment.  It is intended to be used in tests.\n\nThis file is generated from " ++ path ++ " using `elm-gql`\n" ++ Help.renderStandardComment docs
                ]
        }
        (mockFragment paths namespace frag)
        |> Help.replaceFilePath paths.mockModuleFilePath


mockFragment : Generate.Path.Paths -> Namespace -> Can.Fragment -> List Elm.Declaration
mockFragment paths namespace frag =
    case frag.selection of
        Can.FragmentObject { selection } ->
            let
                selectsForOnlyOne =
                    List.length (List.filter (not << Can.isTypeNameSelection) selection) == 1

                primaryObject =
                    Elm.declaration
                        (frag.name
                            |> Can.nameToString
                            |> Utils.String.formatValue
                        )
                        (Elm.record
                            (List.concatMap
                                (\field ->
                                    if Can.isTypeNameSelection field then
                                        []

                                    else
                                        {-
                                           If we are selecting more than one field, we need to
                                           Expand any fragments that we are selecting for

                                           For example, if we have a fragment like this:

                                                item {
                                                    ...Item
                                                }

                                           Then we'd generate

                                                { item : Fragment.Item
                                                }

                                            But if we have

                                                item {
                                                    name
                                                    ...Item
                                                }

                                            Then, we'd want

                                                { item : { name : String, id : Fragment.Item.id, description : Fragment.Item.description }

                                                }


                                        -}
                                        Mock.expandedFields namespace field
                                            |> List.reverse
                                )
                                (List.reverse selection)
                            )
                            |> Elm.withType
                                (Type.named paths.modulePath
                                    (frag.name
                                        |> Can.nameToString
                                        |> Utils.String.formatTypename
                                    )
                                )
                        )
                        |> Elm.exposeWith
                            { exposeConstructor = True
                            , group = Just "primary"
                            }
            in
            primaryObject
                :: generateMockBuilders paths namespace frag

        _ ->
            generateMockBuilders paths namespace frag


generateMockBuilders : Generate.Path.Paths -> Namespace -> Can.Fragment -> List Elm.Declaration
generateMockBuilders paths namespace frag =
    case frag.selection of
        Can.FragmentObject { selection } ->
            List.concatMap
                (Mock.builders paths namespace)
                selection

        Can.FragmentUnion union ->
            List.concatMap
                (Mock.builders paths namespace)
                union.selection
                ++ Mock.variantBuilders paths
                    namespace
                    { globalAlias = frag.name
                    , selectsOnlyFragment = Nothing
                    }
                    union

        Can.FragmentInterface interface ->
            List.concatMap
                (Mock.builders paths namespace)
                interface.selection
                ++ Mock.variantBuilders paths
                    namespace
                    { globalAlias = frag.name
                    , selectsOnlyFragment = Nothing
                    }
                    interface
