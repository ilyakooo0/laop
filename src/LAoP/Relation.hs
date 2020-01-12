-----------------------------------------------------------------------------
-- |
-- Module     : LAoP.Relation
-- Copyright  : (c) Armando Santos 2019-2020
-- Maintainer : armandoifsantos@gmail.com
-- Stability  : experimental
--
-- The AoP discipline generalises functions to relations which are 
-- Boolean matrices.
--
-- This module offers many of the combinators of the Algebra of
-- Programming discipline. It is still under construction and very
-- experimental.
--
-- This is an Internal module and it is no supposed to be imported.
--
-----------------------------------------------------------------------------

module LAoP.Relation
  ( -- | This definition makes use of the fact that 'Void' is
    -- isomorphic to 0 and '()' to 1 and captures matrix
    -- dimensions as stacks of 'Either's.
    --
    -- There exists two type families that make it easier to write
    -- matrix dimensions: 'FromNat' and 'Count'. This approach
    -- leads to a very straightforward implementation 
    -- of LAoP combinators. 

    -- * Relation data type
    Relation (..),
    Boolean,

    -- * Primitives
    empty,
    one,
    junc,
    split,

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
    zeros,
    ones,
    bang,

    -- * Relational operations
    conv,
    intersection,
    union,
    sse,
    ker,
    img,

    -- * Taxonomy of binary relations
    entire,
    injective,
    surjective,
    simple,
    bijective,

    -- * (Endo-)Relational properties
    reflexive,
    coreflexive,
    transitive,
    symmetric,
    antiSymmetric,
    irreflexive,
    connected,
    preorder,
    partialOrder,
    linearOrder,
    equivalence,
    partialEquivalence,

    -- ** McCarthy's Conditional
    -- cond,

    -- * Relational composition and lifting
    identity,
    comp,
    fromF,
    fromF',

    -- * Matrix printing
    pretty,
    prettyPrint
  )
    where

import LAoP.Relation.Internal