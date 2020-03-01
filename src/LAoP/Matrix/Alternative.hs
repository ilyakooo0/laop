{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE StrictData #-}
{-# LANGUAGE TypeFamilyDependencies #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoStarIsType #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

-----------------------------------------------------------------------------
-- |
-- Module     : LAoP.Matrix.Internal
-- Copyright  : (c) Armando Santos 2019-2020
-- Maintainer : armandoifsantos@gmail.com
-- Stability  : experimental
--
-- The LAoP discipline generalises relations and functions treating them as
-- Boolean matrices and in turn consider these as arrows.
--
-- __LAoP__ is a library for algebraic (inductive) construction and manipulation of matrices
-- in Haskell. See <https://github.com/bolt12/master-thesis my Msc Thesis> for the
-- motivation behind the library, the underlying theory, and implementation details.
--
-- This module offers many of the combinators mentioned in the work of
-- Macedo (2012) and Oliveira (2012).
--
-- This is an Internal module and it is no supposed to be imported.
--
-----------------------------------------------------------------------------

module LAoP.Matrix.Alternative
  ( -- | This definition makes use of the fact that 'Void' is
    -- isomorphic to 0 and '()' to 1 and captures matrix
    -- dimensions as stacks of 'Either's.
    --
    -- There exists two type families that make it easier to write
    -- matrix dimensions: 'FromNat' and 'Count'. This approach
    -- leads to a very straightforward implementation
    -- of LAoP combinators.

    -- * Type safe matrix representation
    Matrix (..),

    -- * Primitives
    empty,
    one,
    join,
    fork,

    -- * Auxiliary type families
    FromNat,
    Count,
    Normalize,

    -- * Matrix construction and conversion
    FromLists,
    fromLists,
    toLists,
    toList,
    matrixBuilder,
    matrixBuilderN,
    rowL,
    rowN,
    colL,
    colN,
    zeros,
    ones,
    bang,
    point,
    constant,

    -- * Misc
    -- ** Get dimensions
    columns,
    rows,

    -- ** Matrix Transposition
    tr,

    -- ** Scalar multiplication/division of matrices
    (.|),
    (./),

    -- ** Selective operator
    select,
    branch,

    -- ** McCarthy's Conditional
    -- cond,

    -- ** Matrix "abiding"
    abideJF,
    abideFJ,

    -- ** Zip matrices
    zipWithM,

    -- * Biproduct approach
    -- ** Fork
    (===),
    -- *** Projections
    p1,
    p2,
    -- ** Join
    (|||),
    -- *** Injections
    i1,
    i2,
    -- ** Bifunctors
    (-|-),
    (><),

    -- ** Applicative matrix combinators

    -- | Note that given the restrictions imposed it is not possible to
    -- implement the standard type classes present in standard Haskell.
    -- *** Matrix pairing projections
    fstM,
    sndM,

    -- *** Matrix pairing
    kr,

    -- * Matrix composition and lifting

    -- ** Arrow matrix combinators

    -- | Note that given the restrictions imposed it is not possible to
    -- implement the standard type classes present in standard Haskell.
    iden,
    comp,
    fromF,
    fromFN,

    -- * Matrix printing
    pretty,
    prettyPrint,

    -- * Other
    toBool,
    fromBool,
    compRel,
    divR,
    divL,
    divS,
    fromFRelN,
    toRelN,
    negateM,
    orM,
    andM,
    subM,

    -- * Semantics
    Construct
  )
    where

import LAoP.Utils.Internal
import Data.Bool
import Data.Functor.Contravariant
import Data.Kind
import Data.List
import Data.Maybe
import Data.Proxy
import Data.Void
import GHC.TypeLits
import Data.Type.Equality
import GHC.Generics
import Control.DeepSeq
import Prelude hiding (id, (.))

-- | LAoP (Linear Algebra of Programming) Inductive Matrix definition.
data Matrix e cols rows where
  Empty :: Matrix e Void Void
  One :: e -> Matrix e () ()
  Join :: Matrix e a rows -> Matrix e b rows -> Matrix e (Either a b) rows
  Fork :: Matrix e cols a -> Matrix e cols b -> Matrix e cols (Either a b)

deriving instance (Show e) => Show (Matrix e cols rows)

-- | Type family that computes the cardinality of a given type dimension.
--
--   It can also count the cardinality of custom types that implement the
-- 'Generic' instance.
type family Count (d :: Type) :: Nat where
  Count (Natural n m) = (m - n) + 1
  Count (List a)      = (^) 2 (Count a)
  Count (Either a b)  = (+) (Count a) (Count b)
  Count (a, b)        = (*) (Count a) (Count b)
  Count (a -> b)      = (^) (Count b) (Count a)
  -- Generics
  Count (M1 _ _ f p)  = Count (f p)
  Count (K1 _ _ _)    = 1
  Count (V1 _)        = 0
  Count (U1 _)        = 1
  Count ((:*:) a b p) = Count (a p) * Count (b p)
  Count ((:+:) a b p) = Count (a p) + Count (b p)
  Count d             = Count (Rep d R)

-- | Type family that computes of a given type dimension from a given natural
--
--   Thanks to Li-Yao Xia this type family is super fast.
type family FromNat (n :: Nat) :: Type where
  FromNat 0 = Void
  FromNat 1 = ()
  FromNat n = FromNat' (Mod n 2 == 0) (FromNat (Div n 2))

type family FromNat' (b :: Bool) (m :: Type) :: Type where
  FromNat' 'True m  = Either m m
  FromNat' 'False m = Either () (Either m m)

-- | Type family that normalizes the representation of a given data
-- structure
type family Normalize (d :: Type) :: Type where
  Normalize (Either a b) = Either (Normalize a) (Normalize b)
  Normalize d            = FromNat (Count d)

-- | Constraint type synonyms to keep the type signatures less convoluted
type Countable a             = KnownNat (Count a)
type CountableDimensions a b = (Countable a, Countable b)
type Liftable a b            = (Eq b, Constructable a b, Enumerable a)
type Enumerable a            = (Enum a, Bounded a)
type ConstructNorm a         = (Enum a, Enum (Normalize a))
type ConstructableNorm a b   = (ConstructNorm a, ConstructNorm b)
type ConstructN a            = Construct (Normalize a)
type Constructable a b       = (Construct a, Construct b)
type ConstructableN a b      = (Construct (Normalize a), Construct (Normalize b))

-- | It isn't possible to implement the 'id' function so it's
-- implementation is 'undefined'. However 'comp' can be and this partial
-- class implementation exists just to make the code more readable.
--
-- Please use 'iden' instead.
instance (Num e) => Category (Matrix e) where
  type Object (Matrix e) a = Liftable a a
  id = iden
  (.) = comp

instance NFData e => NFData (Matrix e cols rows) where
    rnf Empty      = ()
    rnf (One e)    = rnf e
    rnf (Join a b) = rnf a `seq` rnf b
    rnf (Fork a b) = rnf a `seq` rnf b

instance Eq e => Eq (Matrix e cols rows) where
  Empty == Empty               = True
  (One a) == (One b)           = a == b
  (Join a b) == (Join c d)     = a == c && b == d
  (Fork a b) == (Fork c d)     = a == c && b == d
  x@(Fork _ _) == y@(Join _ _) = x == abideJF y
  x@(Join _ _) == y@(Fork _ _) = abideJF x == y

instance Num e => Num (Matrix e cols rows) where

  a + b = zipWithM (+) a b

  a - b = zipWithM (-) a b

  a * b = zipWithM (*) a b

  abs Empty      = Empty
  abs (One a)    = One (abs a)
  abs (Join a b) = Join (abs a) (abs b)
  abs (Fork a b) = Fork (abs a) (abs b)

  signum Empty      = Empty
  signum (One a)    = One (signum a)
  signum (Join a b) = Join (signum a) (signum b)
  signum (Fork a b) = Fork (signum a) (signum b)

instance Ord e => Ord (Matrix e cols rows) where
    Empty <= Empty               = True
    (One a) <= (One b)           = a <= b
    (Join a b) <= (Join c d)     = (a <= c) && (b <= d)
    (Fork a b) <= (Fork c d)     = (a <= c) && (b <= d)
    x@(Fork _ _) <= y@(Join _ _) = x <= abideJF y
    x@(Join _ _) <= y@(Fork _ _) = abideJF x <= y

-- Primitives

-- | Empty matrix constructor
empty :: Matrix e Void Void
empty = Empty

-- | Unit matrix constructor
one :: e -> Matrix e () ()
one = One

-- | Matrix 'Join' constructor
join :: Matrix e a rows -> Matrix e b rows -> Matrix e (Either a b) rows
join = Join

infixl 3 |||

-- | Matrix 'Join' constructor
(|||) :: Matrix e a rows -> Matrix e b rows -> Matrix e (Either a b) rows
(|||) = Join

-- | Matrix 'Fork' constructor
fork :: Matrix e cols a -> Matrix e cols b -> Matrix e cols (Either a b)
fork = Fork

infixl 2 ===

-- | Matrix 'Fork' constructor
(===) :: Matrix e cols a -> Matrix e cols b -> Matrix e cols (Either a b)
(===) = Fork

-- Construction

-- | Constructs a column vector matrix
colL :: (FromLists e () rows) => [e] -> Matrix e () rows
colL = fromLists . map (: [])

-- | Constructs a row vector matrix
rowL :: (FromLists e cols ()) => [e] -> Matrix e cols ()
rowL = fromLists . (: [])

-- Conversion

-- | Converts a matrix to a list of lists of elements.
toLists :: Matrix e cols rows -> [[e]]
toLists Empty       = []
toLists (One e)     = [[e]]
toLists (Fork l r)  = toLists l ++ toLists r
toLists (Join l r)  = zipWith (++) (toLists l) (toLists r)

-- | Converts a matrix to a list of elements.
toList :: Matrix e cols rows -> [e]
toList = concat . toLists

-- Zeros Matrix

-- | The zero matrix. A matrix wholly filled with zeros.
zeros :: (Num e, Constructable cols rows, Enumerable cols) => Matrix e cols rows
zeros = matrixBuilder (const 0)

-- Ones Matrix

-- | The ones matrix. A matrix wholly filled with ones.
--
--   Also known as T (Top) matrix.
ones :: (Num e, Constructable cols rows, Enumerable cols) => Matrix e cols rows
ones = matrixBuilder (const 1)

-- Const Matrix

-- | The constant matrix constructor. A matrix wholly filled with a given
-- value.
constant :: (Num e, Constructable cols rows, Enumerable cols) => e -> Matrix e cols rows
constant e = matrixBuilder (const e)

-- Bang Matrix

-- | The T (Top) row vector matrix.
bang :: (Num e, Constructable cols rows, Enumerable cols) => Matrix e cols ()
bang = ones

-- | Point constant matrix
point :: (Num e, Liftable () a) => a -> Matrix e () a
point = fromF . const

-- iden Matrix

-- | iden matrix.
iden :: (Num e, Liftable cols cols) => Matrix e cols cols
iden = fromF id

-- Matrix composition (MMM)

-- | Matrix composition. Equivalent to matrix-matrix multiplication.
--
--   This definition takes advantage of divide-and-conquer and fusion laws
-- from LAoP.
comp :: (Num e) => Matrix e cr rows -> Matrix e cols cr -> Matrix e cols rows
comp Empty Empty           = Empty
comp (One a) (One b)       = One (a * b)
comp (Join a b) (Fork c d) = comp a c + comp b d         -- Divide-and-conquer law
comp (Fork a b) c          = Fork (comp a c) (comp b c) -- Fork fusion law
comp c (Join a b)          = Join (comp c a) (comp c b)  -- Join fusion law
{-# NOINLINE comp #-}
{-# RULES
   "comp/iden1" forall m. comp m iden = m ;
   "comp/iden2" forall m. comp iden m = m
#-}

-- Scalar multiplication of matrices

infixl 7 .|
-- | Scalar multiplication of matrices.
(.|) :: Num e => e -> Matrix e cols rows -> Matrix e cols rows
(.|) _ Empty = Empty
(.|) e (One a) = One (e * a)
(.|) e (Join a b) = Join (e .| a) (e .| b)
(.|) e (Fork a b) = Fork (e .| a) (e .| b)

-- Scalar division of matrices

infixl 7 ./
-- | Scalar multiplication of matrices.
(./) :: Fractional e => Matrix e cols rows -> e -> Matrix e cols rows
(./) Empty _ = Empty
(./) (One a) e = One (a / e)
(./) (Join a b) e = Join (a ./ e) (b ./ e)
(./) (Fork a b) e = Fork (a ./ e) (b ./ e)

-- Projections

-- | Biproduct first component projection
p1 :: (Num e, Eq m, Constructable m n, Enumerable m, Enumerable n) => Matrix e (Either m n) m
p1 = join iden zeros

-- | Biproduct second component projection
p2 :: (Num e, Eq n, Constructable m n, Enumerable m, Enumerable n) => Matrix e (Either m n) n
p2 = join zeros iden

-- Injections

-- | Biproduct first component injection
i1 :: (Num e, Eq m, Constructable m n, Enumerable m, Enumerable n) => Matrix e m (Either m n)
i1 = tr p1

-- | Biproduct second component injection
i2 :: (Num e, Eq n, Constructable m n, Enumerable m, Enumerable n) => Matrix e n (Either m n)
i2 = tr p2

-- Dimensions

-- | Obtain the number of rows.
--
--   NOTE: The 'KnownNat' constaint is needed in order to obtain the
-- dimensions in constant time.
--
-- TODO: A 'rows' function that does not need the 'KnownNat' constraint in
-- exchange for performance.
rows :: forall e cols rows. (Countable rows) => Matrix e cols rows -> Int
rows _ = fromInteger $ natVal (Proxy :: Proxy (Count rows))

-- | Obtain the number of columns.
--
--   NOTE: The 'KnownNat' constaint is needed in order to obtain the
-- dimensions in constant time.
--
-- TODO: A 'columns' function that does not need the 'KnownNat' constraint in
-- exchange for performance.
columns :: forall e cols rows. (Countable cols) => Matrix e cols rows -> Int
columns _ = fromInteger $ natVal (Proxy :: Proxy (Count cols))

-- Coproduct Bifunctor

infixl 5 -|-

-- | Matrix coproduct functor also known as matrix direct sum.
(-|-) ::
  ( Num e,
    Eq k,
    Eq j,
    Constructable k j,
    Enumerable k,
    Enumerable j
  ) => Matrix e n k -> Matrix e m j -> Matrix e (Either n m) (Either k j)
(-|-) a b = Join (i1 . a) (i2 . b)

-- Khatri Rao Product and projections

-- | Khatri Rao product first component projection matrix.
fstM ::
     forall e a b .
     ( Num e,
       Eq a,
       ConstructableN (a, b) a,
       ConstructableNorm (a, b) a,
       Enumerable a,
       Enumerable b
     ) => Matrix e (Normalize (a, b)) (Normalize a)
fstM = fromFN (fst :: (a, b) -> a)

-- | Khatri Rao product second component projection matrix.
sndM ::
     forall e a b .
     ( Num e,
       Eq b,
       ConstructableN (a, b) b,
       ConstructableNorm (a, b) b,
       Enumerable a,
       Enumerable b
     ) => Matrix e (Normalize (a, b)) (Normalize b)
sndM = fromFN (snd :: (a, b) -> b)

-- | Khatri Rao Matrix product also known as matrix pairing.
--
--   NOTE: That this is not a true categorical product, see for instance:
--
-- @
--            | fstM . kr a b == a
-- kr a b ==> |
--            | sndM . kr a b == b
-- @
--
-- __Emphasis__ on the implication symbol.
kr ::
   forall e cols a b .
   ( Num e,
     Eq a,
     Eq b,
     ConstructableN a (a, b),
     ConstructN b,
     ConstructableNorm a b,
     ConstructNorm (a, b),
     Enumerable a,
     Enumerable b
   ) => Matrix e cols (Normalize a) -> Matrix e cols (Normalize b) -> Matrix e cols (Normalize (a, b))
kr a b =
  let fstM' = fstM @e @a @b
      sndM' = sndM @e @a @b
   in (tr fstM' . a) * (tr sndM' . b)

-- Product Bifunctor (Kronecker)

infixl 4 ><

type Kronecker e m n p q = 
  ( Num e,
    Eq m,
    Eq n,
    Eq p,
    Eq q,
    ConstructableN m n,
    ConstructableNorm m (m, n),
    ConstructNorm n,
    ConstructN (m, n),
    ConstructableN p q,
    ConstructableNorm p (p, q),
    ConstructNorm q,
    ConstructN (p, q),
    Enumerable m,
    Enumerable n,
    Enumerable p,
    Enumerable q
  )

-- | Matrix product functor also known as kronecker product
(><) ::
     forall e m p n q .
     Kronecker e m n p q
     => Matrix e (Normalize m) (Normalize p)
     -> Matrix e (Normalize n) (Normalize q)
     -> Matrix e (Normalize (m, n)) (Normalize (p, q))
(><) a b =
  let fstM' = fstM @e @m @n
      sndM' = sndM @e @m @n
   in kr @e @(Normalize (m, n)) @p @q (a . fstM') (b . sndM')

-- Matrix abide Join Fork

-- | Matrix "abiding" following the 'Join'-'Fork' exchange law.
--
-- Law:
--
-- @
-- 'Join' ('Fork' a c) ('Fork' b d) == 'Fork' ('Join' a b) ('Join' c d)
-- @
abideJF :: Matrix e cols rows -> Matrix e cols rows
abideJF (Join (Fork a c) (Fork b d)) = Fork (Join (abideJF a) (abideJF b)) (Join (abideJF c) (abideJF d)) -- Join-Fork abide law
abideJF Empty                        = Empty
abideJF (One e)                      = One e
abideJF (Join a b)                   = Join (abideJF a) (abideJF b)
abideJF (Fork a b)                   = Fork (abideJF a) (abideJF b)

-- Matrix abide Fork Join

-- | Matrix "abiding" followin the 'Fork'-'Join' abide law.
--
-- @
-- 'Fork' ('Join' a b) ('Join' c d) == 'Join' ('Fork' a c) ('Fork' b d)
-- @
abideFJ :: Matrix e cols rows -> Matrix e cols rows
abideFJ (Fork (Join a b) (Join c d)) = Join (Fork (abideFJ a) (abideFJ c)) (Fork (abideFJ b) (abideFJ d)) -- Fork-Join abide law
abideFJ Empty                        = Empty
abideFJ (One e)                      = One e
abideFJ (Join a b)                   = Join (abideFJ a) (abideFJ b)
abideFJ (Fork a b)                   = Fork (abideFJ a) (abideFJ b)

-- Matrix transposition

-- | Matrix transposition.
tr :: Matrix e cols rows -> Matrix e rows cols
tr Empty      = Empty
tr (One e)    = One e
tr (Join a b) = Fork (tr a) (tr b)
tr (Fork a b) = Join (tr a) (tr b)

-- Selective 'select' operator

-- | Selective functors 'select' operator equivalent inspired by the
-- ArrowMonad solution presented in the paper.
select :: (Num e, Liftable b b) => Matrix e cols (Either a b) -> Matrix e a b -> Matrix e cols b
select (Fork a b) y                   = y . a + b                     -- Divide-and-conquer law
select (Join (Fork a c) (Fork b d)) y = join (y . a + c) (y . b + d)  -- Pattern matching + DnC law
select m y                            = join y id . m

branch ::
       ( Num e,
         Eq a,
         Eq b,
         Eq c,
         Constructable a b,
         Construct c,
         Enumerable a,
         Enumerable b,
         Enumerable c
       )
       => Matrix e cols (Either a b) -> Matrix e a c -> Matrix e b c -> Matrix e cols c
branch x l r = f x `select` g l `select` r
  where
    f m = fork (tr i1) (i1 . tr i2) . m
    g m = i2 . m

-- Pretty print

prettyAux :: Show e => [[e]] -> [[e]] -> String
prettyAux [] _     = ""
prettyAux [[e]] m  = "│ " ++ fill (show e) ++ " │\n"
  where
   v  = fmap show m
   widest = maximum $ fmap length v
   fill str = replicate (widest - length str - 2) ' ' ++ str
prettyAux [h] m    = "│ " ++ fill (unwords $ map show h) ++ " │\n"
  where
   v        = fmap show m
   widest   = maximum $ fmap length v
   fill str = replicate (widest - length str - 2) ' ' ++ str
prettyAux (h : t) l = "│ " ++ fill (unwords $ map show h) ++ " │\n" ++
                      prettyAux t l
  where
   v        = fmap show l
   widest   = maximum $ fmap length v
   fill str = replicate (widest - length str - 2) ' ' ++ str

-- | Matrix pretty printer
pretty :: (CountableDimensions cols rows, Show e) => Matrix e cols rows -> String
pretty m = concat
   [ "┌ ", unwords (replicate (columns m) blank), " ┐\n"
   , unlines
   [ "│ " ++ unwords (fmap (\j -> fill $ show $ getElem i j m) [1..columns m]) ++ " │" | i <- [1..rows m] ]
   , "└ ", unwords (replicate (columns m) blank), " ┘"
   ]
 where
   strings  = map show (toList m)
   widest   = maximum $ map length strings
   fill str = replicate (widest - length str) ' ' ++ str
   blank    = fill ""
   safeGet i j m
    | i > rows m || j > columns m || i < 1 || j < 1 = Nothing
    | otherwise = Just $ unsafeGet i j m (toList m)
   unsafeGet i j m l = l !! encode (columns m) (i,j)
   encode m (i,j)    = (i-1)*m + j - 1
   getElem i j m     =
     fromMaybe
       (error $
          "getElem: Trying to get the "
           ++ show (i, j)
           ++ " element from a "
           ++ show (rows m) ++ "x" ++ show (columns m)
           ++ " matrix."
       )
       (safeGet i j m)

-- | Matrix pretty printer
prettyPrint :: (CountableDimensions cols rows, Show e) => Matrix e cols rows -> IO ()
prettyPrint = putStrLn . pretty

-- | Zip two matrices with a given binary function
zipWithM :: (e -> f -> g) -> Matrix e cols rows -> Matrix f cols rows -> Matrix g cols rows
zipWithM _ Empty Empty               = Empty
zipWithM f (One a) (One b)           = One (f a b)
zipWithM f (Join a b) (Join c d)     = Join (zipWithM f a c) (zipWithM f b d)
zipWithM f (Fork a b) (Fork c d)     = Fork (zipWithM f a c) (zipWithM f b d)
zipWithM f x@(Fork _ _) y@(Join _ _) = zipWithM f x (abideJF y)
zipWithM f x@(Join _ _) y@(Fork _ _) = zipWithM f (abideJF x) y

-- Relational operators functions

type Boolean      = Natural 0 1
type Relation a b = Matrix Boolean a b

-- | Helper conversion function
toBool :: (Num e, Eq e) => e -> Bool
toBool n
  | n == 0 = False
  | n == 1 = True

-- | Helper conversion function
fromBool :: Bool -> Natural 0 1
fromBool True  = nat 1
fromBool False = nat 0

-- | Relational negation
negateM :: Relation cols rows -> Relation cols rows
negateM Empty         = Empty
negateM (One (Nat p)) = One (Nat (negate p))
negateM (Join a b)    = Join (negateM a) (negateM b)
negateM (Fork a b)    = Fork (negateM a) (negateM b)

-- | Relational addition
orM :: Relation cols rows -> Relation cols rows -> Relation cols rows
orM Empty Empty               = Empty
orM (One a) (One b)           = One (fromBool (toBool a || toBool b))
orM (Join a b) (Join c d)     = Join (orM a c) (orM b d)
orM (Fork a b) (Fork c d)     = Fork (orM a c) (orM b d)
orM x@(Fork _ _) y@(Join _ _) = orM x (abideJF y)
orM x@(Join _ _) y@(Fork _ _) = orM (abideJF x) y

-- | Relational multiplication
andM :: Relation cols rows -> Relation cols rows -> Relation cols rows
andM Empty Empty               = Empty
andM (One a) (One b)           = One (fromBool (toBool a && toBool b))
andM (Join a b) (Join c d)     = Join (andM a c) (andM b d)
andM (Fork a b) (Fork c d)     = Fork (andM a c) (andM b d)
andM x@(Fork _ _) y@(Join _ _) = andM x (abideJF y)
andM x@(Join _ _) y@(Fork _ _) = andM (abideJF x) y

-- | Relational subtraction
subM :: Relation cols rows -> Relation cols rows -> Relation cols rows
subM Empty Empty               = Empty
subM (One a) (One b)           = if a - b < nat 0 then One (nat 0) else One (a - b)
subM (Join a b) (Join c d)     = Join (subM a c) (subM b d)
subM (Fork a b) (Fork c d)     = Fork (subM a c) (subM b d)
subM x@(Fork _ _) y@(Join _ _) = subM x (abideJF y)
subM x@(Join _ _) y@(Fork _ _) = subM (abideJF x) y

-- | Matrix relational composition.
compRel :: Relation cr rows -> Relation cols cr -> Relation cols rows
compRel Empty Empty           = Empty
compRel (One a) (One b)       = One (fromBool (toBool a && toBool b))
compRel (Join a b) (Fork c d) = orM (compRel a c) (compRel b d)   -- Divide-and-conquer law
compRel (Fork a b) c          = Fork (compRel a c) (compRel b c) -- Fork fusion law
compRel c (Join a b)          = Join (compRel c a) (compRel c b)  -- Join fusion law

-- | Matrix relational right division
divR :: Relation b c -> Relation b a -> Relation a c
divR Empty Empty           = Empty
divR (One a) (One b)       = One (fromBool (not (toBool b) || toBool a)) -- b implies a
divR (Join a b) (Join c d) = andM (divR a c) (divR b d)
divR (Fork a b) c          = Fork (divR a c) (divR b c)
divR c (Fork a b)          = Join (divR c a) (divR c b)

-- | Matrix relational left division
divL :: Relation c b -> Relation a b -> Relation a c
divL x y = tr (divR (tr y) (tr x))

-- | Matrix relational symmetric division
divS :: Relation c a -> Relation b a -> Relation c b
divS s r = divL r s `intersection` divR (tr r) (tr s)
  where
    intersection = andM

-- | Lifts functions to relations with dimensions matching @a@ and @b@
-- cardinality's.
fromFRelN ::
          ( Eq b,
            ConstructableNorm a b,
            ConstructableN a b,
            Enumerable a
          )
          => (a -> b) -> Relation (Normalize a) (Normalize b)
fromFRelN = fromFN

-- | Lifts a relation function to a Boolean Matrix
toRelN ::
      ( ConstructableN a b,
        ConstructableNorm a b,
        Enumerable a
      )
      => (a -> b -> Bool) -> Relation (Normalize a) (Normalize b)
toRelN f = matrixBuilderN (\a -> if uncurry f a then 1 else 0)

----------------------------- Linear map semantics -----------------------------
newtype Vector e a = Vector { at :: a -> e }

instance Contravariant (Vector e) where
    contramap f (Vector g) = Vector (g . f)

instance Num e => Num (Vector e a) where
    fromInteger = Vector . const . fromInteger

    (+)    = liftV2 (+)
    (-)    = liftV2 (-)
    (*)    = liftV2 (*)
    abs    = liftV1 abs
    negate = liftV1 negate
    signum = error "No sensible definition"

liftV1 :: (e -> e) -> Vector e a -> Vector e a
liftV1 f x = Vector (f . at x)

liftV2 :: (e -> e -> e) -> Vector e a -> Vector e a -> Vector e a
liftV2 f x y = Vector (\a -> f (at x a) (at y a))

-- Semantics of Matrix e a b
type LinearMap e a b = Vector e a -> Vector e b

semantics :: Num e => Matrix e a b -> LinearMap e a b
semantics m = case m of
    Empty    -> id
    One e    -> const (Vector (const e))
    Join x y -> \v -> semantics x (Left >$< v) + semantics y (Right >$< v)
    Fork x y -> \v -> Vector $ either (at (semantics x v)) (at (semantics y v))

padLeft :: Num e => Vector e b -> Vector e (Either a b)
padLeft v = Vector $ \case Left _  -> 0
                           Right b -> at v b

padRight :: Num e => Vector e a -> Vector e (Either a b)
padRight v = Vector $ \case Left a  -> at v a
                            Right _ -> 0

dot :: (Num e, Enumerable a) => Vector e a -> Vector e a -> e
dot x y = sum [ at x a * at y a | a <- enumerate ]

--------------------------------- Construction ---------------------------------

class Construct a where
  row :: Num e => Vector e a -> Matrix e a ()

  linearMap :: (Construct b, Num e) => LinearMap e a b -> Matrix e a b

instance Construct () where
  row v = one (at v ())

  linearMap m = col (m 1)

instance (Constructable a b) => Construct (Either a b) where
  row v = row (Left >$< v) ||| row (Right >$< v)

  linearMap m = linearMap (m . padRight) ||| linearMap (m . padLeft)

col :: (Construct a, Num e) => Vector e a -> Matrix e () a
col = tr . row

-- | Matrix builder function. Constructs a matrix provided with
-- a construction function that operates with canonical types.
matrixBuilder :: (Num e, Constructable a b, Enumerable a) => ((a, b) -> e) -> Matrix e a b
matrixBuilder f = linearMap $ \v -> Vector $ \b -> dot v $ Vector $ \a -> f (a, b)

-- | Lifts functions to matrices.
fromF :: (Num e, Liftable a b) => (a -> b) -> Matrix e a b
fromF f = matrixBuilder (\(a, b) -> if f a == b then 1 else 0)

-------------------------------- Deconstruction --------------------------------
enumerate :: Enumerable a => [a]
enumerate = [minBound .. maxBound]

basis :: (Enumerable a, Eq a, Num e) => [Vector e a]
basis = [ Vector (bool 0 1 . (==a)) | a <- enumerate ]

toLists' :: (Enumerable a, Enumerable b, Eq a, Num e) => Matrix e a b -> [[e]]
toLists' m = transpose
    [ [ at r i | i <- enumerate ] | c <- basis, let r = semantics m c ]

dump :: (Enumerable a, Enumerable b, Eq a, Num e, Show e) => Matrix e a b -> IO ()
dump = mapM_ print . toLists'

------------------------------- Normalised types -------------------------------
class Profunctor p where
    dimap :: (a -> b) -> (c -> d) -> p b c -> p a d

instance Profunctor (->) where
    dimap f g h = g . h . f

toNorm :: ConstructNorm a => a -> Normalize a
toNorm = toEnum . fromEnum

fromNorm :: ConstructNorm a => Normalize a -> a
fromNorm = toEnum . fromEnum

rowN :: (ConstructN a, ConstructNorm a, Num e) => Vector e a -> Matrix e (Normalize a) ()
rowN = row . contramap fromNorm

linearMapN :: (ConstructableN a b, ConstructableNorm a b, Num e)
           => LinearMap e a b -> Matrix e (Normalize a) (Normalize b)
linearMapN = linearMap . dimap (contramap toNorm) (contramap fromNorm)

colN :: (ConstructN a, ConstructNorm a, Num e) => Vector e a -> Matrix e () (Normalize a)
colN = tr . rowN

-- | Matrix builder function. Constructs a matrix provided with
-- a construction function that operates with arbitrary types.
matrixBuilderN :: (Num e, ConstructableN a b, ConstructableNorm a b, Enumerable a)
               => ((a, b) -> e) -> Matrix e (Normalize a) (Normalize b)
matrixBuilderN f = linearMapN $ \v -> Vector $ \b -> dot v $ Vector $ \a -> f (a, b)

-- | Lifts functions to matrices with dimensions matching @a@ and @b@
-- cardinality's.
fromFN :: (Num e, Eq b, ConstructableN a b, ConstructableNorm a b, Enumerable a)
       => (a -> b) -> Matrix e (Normalize a) (Normalize b)
fromFN f = matrixBuilderN (\(a, b) -> if f a == b then 1 else 0)

------------------------------- Unsafe fromLists matrix construction -------------------------------

-- | Type class for defining the 'fromList' conversion function.
--
--   Given that it is not possible to branch on types at the term level type
-- classes are needed very much like an inductive definition but on types.
class FromLists e cols rows where
  -- | Build a matrix out of a list of list of elements. Throws a runtime
  -- error if the dimensions do not match.
  fromLists :: [[e]] -> Matrix e cols rows

instance FromLists e Void Void where
  fromLists [] = Empty
  fromLists _  = error "Wrong dimensions"

instance {-# OVERLAPPING #-} FromLists e () () where
  fromLists [[e]] = One e
  fromLists _     = error "Wrong dimensions"

instance {-# OVERLAPPING #-} (FromLists e cols ()) => FromLists e (Either () cols) () where
  fromLists [h : t] = Join (One h) (fromLists [t])
  fromLists _       = error "Wrong dimensions"

instance {-# OVERLAPPABLE #-} (FromLists e a (), FromLists e b (), Countable a) => FromLists e (Either a b) () where
  fromLists [l] =
      let rowsA = fromInteger (natVal (Proxy :: Proxy (Count a)))
       in Join (fromLists [take rowsA l]) (fromLists [drop rowsA l])
  fromLists _       = error "Wrong dimensions"

instance {-# OVERLAPPING #-} (FromLists e () rows) => FromLists e () (Either () rows) where
  fromLists ([h] : t) = Fork (One h) (fromLists t)
  fromLists _         = error "Wrong dimensions"

instance {-# OVERLAPPABLE #-} (FromLists e () a, FromLists e () b, Countable a) => FromLists e () (Either a b) where
  fromLists l@([_] : _) =
      let rowsA = fromInteger (natVal (Proxy :: Proxy (Count a)))
       in Fork (fromLists (take rowsA l)) (fromLists (drop rowsA l))
  fromLists _         = error "Wrong dimensions"

instance {-# OVERLAPPABLE #-} (FromLists e (Either a b) c, FromLists e (Either a b) d, Countable c) => FromLists e (Either a b) (Either c d) where
  fromLists l@(h : t) =
    let lh        = length h
        rowsC     = fromInteger (natVal (Proxy :: Proxy (Count c)))
        condition = all ((== lh) . length) t
     in if lh > 0 && condition
          then Fork (fromLists (take rowsC l)) (fromLists (drop rowsC l))
          else error "Not all rows have the same length"
