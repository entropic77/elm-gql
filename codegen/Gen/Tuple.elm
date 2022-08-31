module Gen.Tuple exposing (call_, first, mapBoth, mapFirst, mapSecond, moduleName_, pair, second, values_)

{-| 
@docs moduleName_, pair, first, second, mapFirst, mapSecond, mapBoth, call_, values_
-}


import Elm
import Elm.Annotation as Type


{-| The name of this module. -}
moduleName_ : List String
moduleName_ =
    [ "Tuple" ]


{-| Create a 2-tuple.

    -- pair 3 4 == (3, 4)

    zip : List a -> List b -> List (a, b)
    zip xs ys =
      List.map2 Tuple.pair xs ys

pair: a -> b -> ( a, b )
-}
pair : Elm.Expression -> Elm.Expression -> Elm.Expression
pair pairArg pairArg0 =
    Elm.apply
        (Elm.value
            { importFrom = [ "Tuple" ]
            , name = "pair"
            , annotation =
                Just
                    (Type.function
                        [ Type.var "a", Type.var "b" ]
                        (Type.tuple (Type.var "a") (Type.var "b"))
                    )
            }
        )
        [ pairArg, pairArg0 ]


{-| Extract the first value from a tuple.

    first (3, 4) == 3
    first ("john", "doe") == "john"

first: ( a, b ) -> a
-}
first : Elm.Expression -> Elm.Expression
first firstArg =
    Elm.apply
        (Elm.value
            { importFrom = [ "Tuple" ]
            , name = "first"
            , annotation =
                Just
                    (Type.function
                        [ Type.tuple (Type.var "a") (Type.var "b") ]
                        (Type.var "a")
                    )
            }
        )
        [ firstArg ]


{-| Extract the second value from a tuple.

    second (3, 4) == 4
    second ("john", "doe") == "doe"

second: ( a, b ) -> b
-}
second : Elm.Expression -> Elm.Expression
second secondArg =
    Elm.apply
        (Elm.value
            { importFrom = [ "Tuple" ]
            , name = "second"
            , annotation =
                Just
                    (Type.function
                        [ Type.tuple (Type.var "a") (Type.var "b") ]
                        (Type.var "b")
                    )
            }
        )
        [ secondArg ]


{-| Transform the first value in a tuple.

    import String

    mapFirst String.reverse ("stressed", 16) == ("desserts", 16)
    mapFirst String.length  ("stressed", 16) == (8, 16)

mapFirst: (a -> x) -> ( a, b ) -> ( x, b )
-}
mapFirst :
    (Elm.Expression -> Elm.Expression) -> Elm.Expression -> Elm.Expression
mapFirst mapFirstArg mapFirstArg0 =
    Elm.apply
        (Elm.value
            { importFrom = [ "Tuple" ]
            , name = "mapFirst"
            , annotation =
                Just
                    (Type.function
                        [ Type.function [ Type.var "a" ] (Type.var "x")
                        , Type.tuple (Type.var "a") (Type.var "b")
                        ]
                        (Type.tuple (Type.var "x") (Type.var "b"))
                    )
            }
        )
        [ Elm.functionReduced "mapFirstUnpack" mapFirstArg, mapFirstArg0 ]


{-| Transform the second value in a tuple.

    mapSecond sqrt   ("stressed", 16) == ("stressed", 4)
    mapSecond negate ("stressed", 16) == ("stressed", -16)

mapSecond: (b -> y) -> ( a, b ) -> ( a, y )
-}
mapSecond :
    (Elm.Expression -> Elm.Expression) -> Elm.Expression -> Elm.Expression
mapSecond mapSecondArg mapSecondArg0 =
    Elm.apply
        (Elm.value
            { importFrom = [ "Tuple" ]
            , name = "mapSecond"
            , annotation =
                Just
                    (Type.function
                        [ Type.function [ Type.var "b" ] (Type.var "y")
                        , Type.tuple (Type.var "a") (Type.var "b")
                        ]
                        (Type.tuple (Type.var "a") (Type.var "y"))
                    )
            }
        )
        [ Elm.functionReduced "mapSecondUnpack" mapSecondArg, mapSecondArg0 ]


{-| Transform both parts of a tuple.

    import String

    mapBoth String.reverse sqrt  ("stressed", 16) == ("desserts", 4)
    mapBoth String.length negate ("stressed", 16) == (8, -16)

mapBoth: (a -> x) -> (b -> y) -> ( a, b ) -> ( x, y )
-}
mapBoth :
    (Elm.Expression -> Elm.Expression)
    -> (Elm.Expression -> Elm.Expression)
    -> Elm.Expression
    -> Elm.Expression
mapBoth mapBothArg mapBothArg0 mapBothArg1 =
    Elm.apply
        (Elm.value
            { importFrom = [ "Tuple" ]
            , name = "mapBoth"
            , annotation =
                Just
                    (Type.function
                        [ Type.function [ Type.var "a" ] (Type.var "x")
                        , Type.function [ Type.var "b" ] (Type.var "y")
                        , Type.tuple (Type.var "a") (Type.var "b")
                        ]
                        (Type.tuple (Type.var "x") (Type.var "y"))
                    )
            }
        )
        [ Elm.functionReduced "mapBothUnpack" mapBothArg
        , Elm.functionReduced "mapBothUnpack" mapBothArg0
        , mapBothArg1
        ]


call_ :
    { pair : Elm.Expression -> Elm.Expression -> Elm.Expression
    , first : Elm.Expression -> Elm.Expression
    , second : Elm.Expression -> Elm.Expression
    , mapFirst : Elm.Expression -> Elm.Expression -> Elm.Expression
    , mapSecond : Elm.Expression -> Elm.Expression -> Elm.Expression
    , mapBoth :
        Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
    }
call_ =
    { pair =
        \pairArg pairArg0 ->
            Elm.apply
                (Elm.value
                    { importFrom = [ "Tuple" ]
                    , name = "pair"
                    , annotation =
                        Just
                            (Type.function
                                [ Type.var "a", Type.var "b" ]
                                (Type.tuple (Type.var "a") (Type.var "b"))
                            )
                    }
                )
                [ pairArg, pairArg0 ]
    , first =
        \firstArg ->
            Elm.apply
                (Elm.value
                    { importFrom = [ "Tuple" ]
                    , name = "first"
                    , annotation =
                        Just
                            (Type.function
                                [ Type.tuple (Type.var "a") (Type.var "b") ]
                                (Type.var "a")
                            )
                    }
                )
                [ firstArg ]
    , second =
        \secondArg ->
            Elm.apply
                (Elm.value
                    { importFrom = [ "Tuple" ]
                    , name = "second"
                    , annotation =
                        Just
                            (Type.function
                                [ Type.tuple (Type.var "a") (Type.var "b") ]
                                (Type.var "b")
                            )
                    }
                )
                [ secondArg ]
    , mapFirst =
        \mapFirstArg mapFirstArg0 ->
            Elm.apply
                (Elm.value
                    { importFrom = [ "Tuple" ]
                    , name = "mapFirst"
                    , annotation =
                        Just
                            (Type.function
                                [ Type.function [ Type.var "a" ] (Type.var "x")
                                , Type.tuple (Type.var "a") (Type.var "b")
                                ]
                                (Type.tuple (Type.var "x") (Type.var "b"))
                            )
                    }
                )
                [ mapFirstArg, mapFirstArg0 ]
    , mapSecond =
        \mapSecondArg mapSecondArg0 ->
            Elm.apply
                (Elm.value
                    { importFrom = [ "Tuple" ]
                    , name = "mapSecond"
                    , annotation =
                        Just
                            (Type.function
                                [ Type.function [ Type.var "b" ] (Type.var "y")
                                , Type.tuple (Type.var "a") (Type.var "b")
                                ]
                                (Type.tuple (Type.var "a") (Type.var "y"))
                            )
                    }
                )
                [ mapSecondArg, mapSecondArg0 ]
    , mapBoth =
        \mapBothArg mapBothArg0 mapBothArg1 ->
            Elm.apply
                (Elm.value
                    { importFrom = [ "Tuple" ]
                    , name = "mapBoth"
                    , annotation =
                        Just
                            (Type.function
                                [ Type.function [ Type.var "a" ] (Type.var "x")
                                , Type.function [ Type.var "b" ] (Type.var "y")
                                , Type.tuple (Type.var "a") (Type.var "b")
                                ]
                                (Type.tuple (Type.var "x") (Type.var "y"))
                            )
                    }
                )
                [ mapBothArg, mapBothArg0, mapBothArg1 ]
    }


values_ :
    { pair : Elm.Expression
    , first : Elm.Expression
    , second : Elm.Expression
    , mapFirst : Elm.Expression
    , mapSecond : Elm.Expression
    , mapBoth : Elm.Expression
    }
values_ =
    { pair =
        Elm.value
            { importFrom = [ "Tuple" ]
            , name = "pair"
            , annotation =
                Just
                    (Type.function
                        [ Type.var "a", Type.var "b" ]
                        (Type.tuple (Type.var "a") (Type.var "b"))
                    )
            }
    , first =
        Elm.value
            { importFrom = [ "Tuple" ]
            , name = "first"
            , annotation =
                Just
                    (Type.function
                        [ Type.tuple (Type.var "a") (Type.var "b") ]
                        (Type.var "a")
                    )
            }
    , second =
        Elm.value
            { importFrom = [ "Tuple" ]
            , name = "second"
            , annotation =
                Just
                    (Type.function
                        [ Type.tuple (Type.var "a") (Type.var "b") ]
                        (Type.var "b")
                    )
            }
    , mapFirst =
        Elm.value
            { importFrom = [ "Tuple" ]
            , name = "mapFirst"
            , annotation =
                Just
                    (Type.function
                        [ Type.function [ Type.var "a" ] (Type.var "x")
                        , Type.tuple (Type.var "a") (Type.var "b")
                        ]
                        (Type.tuple (Type.var "x") (Type.var "b"))
                    )
            }
    , mapSecond =
        Elm.value
            { importFrom = [ "Tuple" ]
            , name = "mapSecond"
            , annotation =
                Just
                    (Type.function
                        [ Type.function [ Type.var "b" ] (Type.var "y")
                        , Type.tuple (Type.var "a") (Type.var "b")
                        ]
                        (Type.tuple (Type.var "a") (Type.var "y"))
                    )
            }
    , mapBoth =
        Elm.value
            { importFrom = [ "Tuple" ]
            , name = "mapBoth"
            , annotation =
                Just
                    (Type.function
                        [ Type.function [ Type.var "a" ] (Type.var "x")
                        , Type.function [ Type.var "b" ] (Type.var "y")
                        , Type.tuple (Type.var "a") (Type.var "b")
                        ]
                        (Type.tuple (Type.var "x") (Type.var "y"))
                    )
            }
    }


