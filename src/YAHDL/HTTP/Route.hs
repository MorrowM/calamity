-- | The route type

{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE EmptyCase #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module YAHDL.HTTP.Route
  ( mkRouteBuilder
  , giveID
  , buildRoute
  , RouteBuilder
  , Route
  , SFragment(..)
  , ID(..)
  , RouteFragmentable(..)
  , RouteMethod(..)
  )
where

import           Data.Maybe                     ( fromJust )
import           Data.Singletons.Prelude.List
import           Data.Singletons.Prelude
import           Data.Singletons.TH
import           Data.List                      ( lookup )

import           YAHDL.Types.Snowflake

data RouteFragment
  = SFragment' Text
  | ID' TypeRep
  deriving (Generic, Show, Eq)

newtype SFragment = SFragment Text
data ID a = ID

instance Hashable RouteFragment

data RouteMethod
  = GET
  | POST
  | DELETE
  | PUT
  deriving (Generic, Show, Eq)

instance Hashable RouteMethod

$(singletons [d|
  data RouteRequirement = NotNeeded | Required | Satisfied
    deriving (Generic, Show, Eq)
  |])

data RouteBuilder (idState :: [(Type, RouteRequirement)]) = UnsafeMkRouteBuilder
  { method  :: RouteMethod
  , route   :: [RouteFragment]
  , ids     :: [(TypeRep, Word64)]
  }

mkRouteBuilder :: RouteMethod -> RouteBuilder '[]
mkRouteBuilder method = UnsafeMkRouteBuilder method [] []

giveID
  :: forall k ids
   . (Lookup k ids ~ 'Just 'Required, Typeable k)
  => RouteBuilder ids
  -> Snowflake k
  -> RouteBuilder ('(k, 'Satisfied) ': ids)
giveID (UnsafeMkRouteBuilder method route ids) (Snowflake id) =
  UnsafeMkRouteBuilder method route ((typeRep (Proxy :: Proxy k), id) : ids)

$(singletons [d|
  isFulfilled :: forall k. Eq k => [(k, RouteRequirement)] -> Bool
  isFulfilled = go []
    where go :: [k] -> [(k, RouteRequirement)] -> Bool
          go _ [] = True
          go seen ((k, NotNeeded) : xs) = go (k : seen) xs
          go seen ((k, Satisfied) : xs) = go (k : seen) xs
          go seen ((k, Required) : xs) = (elem k seen && go seen xs)
  |])

$(singletons [d|
  addRequired :: Eq k => k -> [(k, RouteRequirement)] -> [(k, RouteRequirement)]
  addRequired k l = (k, go e) : l
    where go :: Maybe RouteRequirement -> RouteRequirement
          go (Just NotNeeded) = Required
          go (Just Required)  = Required
          go (Just Satisfied) = Satisfied
          go Nothing          = Required
          e = lookup k l
  |])

class Typeable a => RouteFragmentable a ids where
  type ConsRes a ids

  (!:!) :: a -> RouteBuilder ids -> ConsRes a ids

instance RouteFragmentable SFragment ids where
  type ConsRes SFragment ids = RouteBuilder ids

  (SFragment t) !:! (UnsafeMkRouteBuilder m r ids) =
    UnsafeMkRouteBuilder m (SFragment' t : r) ids

instance Typeable a => RouteFragmentable (ID (a :: Type)) (ids :: [(Type, RouteRequirement)]) where
  type ConsRes (ID a) ids = RouteBuilder (AddRequired a ids)

  ID !:! (UnsafeMkRouteBuilder m r ids) =
    UnsafeMkRouteBuilder m (ID' (typeRep (Proxy :: Proxy a)) : r) ids

infixr 5 !:!

data Route = Route RouteMethod [Text]
  deriving (Generic, Show, Eq)

instance Hashable Route

buildRoute
  :: IsFulfilled ids ~ 'True
  => RouteBuilder (ids :: [(Type, RouteRequirement)])
  -> Route
buildRoute (UnsafeMkRouteBuilder method route ids) = Route method
                                                           (map go route)
 where
  go (SFragment' t) = t
  go (ID'        t) = show . fromJust $ lookup t ids
