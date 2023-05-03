export default (): string => "module GraphQL.Operations.Parse exposing (errorToString, parse)\n\n{-| This code was originally borrowed from <https://github.com/lukewestby/elm-graphql-parser>\n-}\n\nimport Char\nimport GraphQL.Operations.AST as AST\nimport Parser exposing (..)\nimport Set exposing (Set)\n\n\nmultiOr : List (a -> Bool) -> a -> Bool\nmultiOr conds val =\n    List.foldl\n        (\\next memo ->\n            if memo then\n                memo\n\n            else\n                next val\n        )\n        False\n        conds\n\n\nkeywords : Set String\nkeywords =\n    Set.empty\n\n\nignoreChars : Set Char\nignoreChars =\n    Set.fromList\n        [ '\\t'\n        , '\\n'\n        , chars.cr\n        , ' '\n        , ','\n        ]\n\n\nchars : { cr : Char }\nchars =\n    { cr =\n        Char.fromCode 0x0D\n    }\n\n\nws : Parser ()\nws =\n    Parser.chompWhile\n        (\\c ->\n            Set.member c ignoreChars\n        )\n\n\nname : Parser AST.Name\nname =\n    Parser.variable\n        { start = multiOr [ Char.isAlpha, (==) '_' ]\n        , inner = multiOr [ Char.isAlphaNum, (==) '_' ]\n        , reserved = keywords\n        }\n        |> Parser.map AST.Name\n\n\nvariable : Parser AST.Variable\nvariable =\n    succeed AST.Variable\n        |. symbol \"$\"\n        |= name\n\n\nboolValue : Parser AST.Value\nboolValue =\n    Parser.oneOf\n        [ Parser.map (\\_ -> AST.Boolean True) (keyword \"true\")\n        , Parser.map (\\_ -> AST.Boolean False) (keyword \"false\")\n        ]\n\n\n{-|\n\n    Of note!\n\n    The Elm Parser.int and Parser.float parsers are broken as they can accept values that start with 'e'\n\n    : https://github.com/elm/parser/issues/25\n\n-}\nintOrFloat : Parser AST.Value\nintOrFloat =\n    Parser.succeed\n        (\\firstPart maybeSecond ->\n            case maybeSecond of\n                Nothing ->\n                    String.toInt firstPart\n                        |> Maybe.withDefault 0\n                        |> AST.Integer\n\n                Just second ->\n                    String.toFloat (firstPart ++ second)\n                        |> Maybe.withDefault 0\n                        |> AST.Decimal\n        )\n        |= Parser.getChompedString\n            (Parser.succeed identity\n                |. Parser.chompIf Char.isDigit\n                |. Parser.chompWhile Char.isDigit\n            )\n        |= Parser.oneOf\n            [ Parser.map Just\n                (Parser.getChompedString\n                    (Parser.succeed ()\n                        |. Parser.chompIf (\\c -> c == '.')\n                        |. Parser.chompWhile Char.isDigit\n                    )\n                )\n            , Parser.succeed Nothing\n            ]\n\n\nstringValue : Parser AST.Value\nstringValue =\n    succeed AST.Str\n        |. symbol \"\\\"\"\n        |= Parser.getChompedString\n            (Parser.chompWhile (\\c -> c /= chars.cr && c /= '\\n' && c /= '\"'))\n        |. symbol \"\\\"\"\n\n\nenumValue : Parser AST.Value\nenumValue =\n    Parser.map AST.Enum name\n\n\nlistValue : (() -> Parser AST.Value) -> Parser AST.Value\nlistValue valueParser =\n    Parser.map AST.ListValue <|\n        Parser.sequence\n            { start = \"[\"\n            , separator = \"\"\n            , end = \"]\"\n            , spaces = ws\n            , item = lazy valueParser\n            , trailing = Parser.Optional\n            }\n\n\nkvp_ : (() -> Parser AST.Value) -> Parser ( AST.Name, AST.Value )\nkvp_ valueParser =\n    succeed Tuple.pair\n        |= name\n        |. ws\n        |. symbol \":\"\n        |. ws\n        |= lazy valueParser\n\n\nobjectValue : (() -> Parser AST.Value) -> Parser AST.Value\nobjectValue valueParser =\n    Parser.map AST.Object <|\n        Parser.sequence\n            { start = \"{\"\n            , separator = \"\"\n            , end = \"}\"\n            , spaces = ws\n            , item = kvp_ valueParser\n            , trailing = Parser.Optional\n            }\n\n\nnullValue : Parser AST.Value\nnullValue =\n    Parser.map (\\_ -> AST.Null) <| keyword \"null\"\n\n\nvalue : Parser AST.Value\nvalue =\n    Parser.oneOf\n        [ boolValue\n        , nullValue\n        , intOrFloat\n        , stringValue\n        , enumValue\n        , Parser.map AST.Var variable\n        , listValue (\\() -> value)\n        , objectValue (\\() -> value)\n        ]\n\n\nkvp : Parser ( AST.Name, AST.Value )\nkvp =\n    kvp_ (\\() -> value)\n\n\nloopItems contentParser items =\n    ifProgress List.reverse <|\n        Parser.oneOf\n            [ Parser.map (\\d -> d :: items) contentParser\n            , Parser.succeed items\n                |. comment\n            , Parser.map (\\_ -> items) ws\n            ]\n\n\nselectionSet : Parser (List AST.Selection)\nselectionSet =\n    Parser.succeed identity\n        |. Parser.symbol \"{\"\n        |. ws\n        |= Parser.loop []\n            (loopItems\n                (Parser.lazy\n                    (\\() ->\n                        Parser.oneOf\n                            [ Parser.map AST.Field field_\n                            , inlineOrSpread_\n                            ]\n                    )\n                )\n            )\n        |. ws\n        |. Parser.symbol \"}\"\n\n\ncomment : Parser ()\ncomment =\n    Parser.succeed ()\n        |. Parser.symbol \"#\"\n        |. Parser.chompWhile\n            (\\c ->\n                c /= '\\n'\n            )\n        |. Parser.symbol \"\\n\"\n\n\ninlineOrSpread_ : Parser AST.Selection\ninlineOrSpread_ =\n    Parser.succeed identity\n        |. Parser.symbol \"...\"\n        |. ws\n        |= Parser.oneOf\n            [ Parser.map AST.InlineFragmentSelection <|\n                Parser.succeed AST.InlineFragment\n                    |. Parser.keyword \"on\"\n                    |. ws\n                    |= name\n                    |. ws\n                    |= directives\n                    |. ws\n                    |= selectionSet\n            , Parser.map AST.FragmentSpreadSelection <|\n                Parser.succeed AST.FragmentSpread\n                    |= name\n                    |. ws\n                    |= directives\n            ]\n\n\nfield_ : Parser AST.FieldDetails\nfield_ =\n    Parser.succeed\n        (\\( alias_, foundName ) args dirs sels ->\n            { alias_ = alias_\n            , name = foundName\n            , arguments = args\n            , directives = dirs\n            , selection = sels\n            }\n        )\n        |= aliasedName\n        |. ws\n        |= argumentsOpt\n        |. ws\n        |= directives\n        |. ws\n        |= Parser.oneOf\n            [ selectionSet\n            , Parser.succeed []\n            ]\n\n\naliasedName : Parser ( Maybe AST.Name, AST.Name )\naliasedName =\n    Parser.succeed\n        (\\nameOrAlias maybeActualName ->\n            case maybeActualName of\n                Nothing ->\n                    ( Nothing, nameOrAlias )\n\n                Just actualName ->\n                    ( Just nameOrAlias, actualName )\n        )\n        |= name\n        |= Parser.oneOf\n            [ Parser.succeed Just\n                |. Parser.chompIf (\\c -> c == ':')\n                |. ws\n                |= name\n            , Parser.succeed Nothing\n            ]\n\n\nargument : Parser AST.Argument\nargument =\n    Parser.map (\\( key, v ) -> AST.Argument key v) kvp\n\n\narguments : Parser (List AST.Argument)\narguments =\n    Parser.sequence\n        { start = \"(\"\n        , separator = \"\"\n        , end = \")\"\n        , spaces = ws\n        , item = argument\n        , trailing = Parser.Optional\n        }\n\n\nargumentsOpt : Parser (List AST.Argument)\nargumentsOpt =\n    oneOf\n        [ arguments\n        , Parser.succeed []\n        ]\n\n\ndirective : Parser AST.Directive\ndirective =\n    succeed AST.Directive\n        |. symbol \"@\"\n        |. ws\n        |= name\n        |. ws\n        |= argumentsOpt\n\n\ndirectives : Parser (List AST.Directive)\ndirectives =\n    Parser.loop []\n        directivesHelper\n\n\ndirectivesHelper :\n    List AST.Directive\n    -> Parser (Parser.Step (List AST.Directive) (List AST.Directive))\ndirectivesHelper dirs =\n    ifProgress List.reverse <|\n        Parser.oneOf\n            [ Parser.map (\\d -> d :: dirs) directive\n            , Parser.map (\\_ -> dirs) ws\n            ]\n\n\nfragment : Parser AST.FragmentDetails\nfragment =\n    succeed AST.FragmentDetails\n        |. keyword \"fragment\"\n        |. ws\n        |= name\n        |. ws\n        |. keyword \"on\"\n        |. ws\n        |= name\n        |. ws\n        |= directives\n        |. ws\n        |= selectionSet\n\n\nnameOpt : Parser (Maybe AST.Name)\nnameOpt =\n    oneOf\n        [ Parser.map Just name\n        , succeed Nothing\n        ]\n\n\noperationType : Parser AST.OperationType\noperationType =\n    oneOf\n        [ Parser.map (\\_ -> AST.Query) <| keyword \"query\"\n        , Parser.map (\\_ -> AST.Mutation) <| keyword \"mutation\"\n        ]\n\n\ndefaultValue : Parser (Maybe AST.Value)\ndefaultValue =\n    oneOf\n        [ Parser.map Just <|\n            succeed identity\n                |. symbol \"=\"\n                |. ws\n                |= value\n        , succeed Nothing\n        ]\n\n\nlistType : (() -> Parser AST.Type) -> Parser AST.Type\nlistType typeParser =\n    succeed identity\n        |. symbol \"[\"\n        |. ws\n        |= lazy typeParser\n        |. ws\n        |. symbol \"]\"\n\n\ntype_ : Parser AST.Type\ntype_ =\n    Parser.succeed\n        (\\base isRequired ->\n            if isRequired then\n                base\n\n            else\n                AST.Nullable base\n        )\n        |= Parser.oneOf\n            [ Parser.map AST.Type_ name\n            , Parser.map AST.List_ (listType (\\_ -> type_))\n            ]\n        |= Parser.oneOf\n            [ Parser.succeed True\n                |. Parser.symbol \"!\"\n            , Parser.succeed False\n            ]\n\n\nvariableDefinition : Parser AST.VariableDefinition\nvariableDefinition =\n    succeed AST.VariableDefinition\n        |= variable\n        |. ws\n        |. symbol \":\"\n        |. ws\n        |= type_\n        |. ws\n        |= defaultValue\n\n\nvariableDefinitions : Parser (List AST.VariableDefinition)\nvariableDefinitions =\n    oneOf\n        [ Parser.sequence\n            { start = \"(\"\n            , separator = \"\"\n            , end = \")\"\n            , spaces = ws\n            , item = variableDefinition\n            , trailing = Parser.Optional\n            }\n        , Parser.succeed []\n        ]\n\n\noperation : Parser AST.OperationDetails\noperation =\n    Parser.succeed AST.OperationDetails\n        |= operationType\n        |. ws\n        |= nameOpt\n        |. ws\n        |= variableDefinitions\n        |. ws\n        |= directives\n        |. ws\n        |= selectionSet\n\n\ndefinition : Parser AST.Definition\ndefinition =\n    Parser.oneOf\n        [ Parser.map AST.Fragment fragment\n        , Parser.map AST.Operation operation\n        ]\n\n\nloopDefinitions defs =\n    ifProgress List.reverse <|\n        Parser.oneOf\n            [ Parser.map (\\_ -> defs) comment\n            , Parser.map (\\d -> d :: defs) definition\n            , Parser.map (\\_ -> defs) ws\n            ]\n\n\ndocumentParser : Parser AST.Document\ndocumentParser =\n    Parser.succeed AST.Document\n        |. ws\n        |= Parser.loop []\n            loopDefinitions\n        |. ws\n        |. Parser.end\n\n\nparse : String -> Result (List Parser.DeadEnd) AST.Document\nparse doc =\n    Parser.run documentParser doc\n\n\nifProgress : (step -> done) -> Parser step -> Parser (Step step done)\nifProgress onSucceed parser =\n    Parser.succeed\n        (\\oldOffset parsed newOffset ->\n            if oldOffset == newOffset then\n                Done (onSucceed parsed)\n\n            else\n                Loop parsed\n        )\n        |= Parser.getOffset\n        |= parser\n        |= Parser.getOffset\n\n\nerrorToString : List Parser.DeadEnd -> String\nerrorToString deadEnds =\n    String.concat (List.intersperse \"; \" (List.map deadEndToString deadEnds))\n\n\ndeadEndToString : Parser.DeadEnd -> String\ndeadEndToString deadend =\n    problemToString deadend.problem\n        ++ \" at row \"\n        ++ String.fromInt deadend.row\n        ++ \", col \"\n        ++ String.fromInt deadend.col\n\n\nproblemToString : Parser.Problem -> String\nproblemToString p =\n    case p of\n        Expecting s ->\n            \"expecting '\" ++ s ++ \"'\"\n\n        ExpectingInt ->\n            \"expecting int\"\n\n        ExpectingHex ->\n            \"expecting hex\"\n\n        ExpectingOctal ->\n            \"expecting octal\"\n\n        ExpectingBinary ->\n            \"expecting binary\"\n\n        ExpectingFloat ->\n            \"expecting float\"\n\n        ExpectingNumber ->\n            \"expecting number\"\n\n        ExpectingVariable ->\n            \"expecting variable\"\n\n        ExpectingSymbol s ->\n            \"expecting symbol '\" ++ s ++ \"'\"\n\n        ExpectingKeyword s ->\n            \"expecting keyword '\" ++ s ++ \"'\"\n\n        ExpectingEnd ->\n            \"expecting end\"\n\n        UnexpectedChar ->\n            \"unexpected char\"\n\n        Problem s ->\n            \"problem \" ++ s\n\n        BadRepeat ->\n            \"bad repeat\"\n"