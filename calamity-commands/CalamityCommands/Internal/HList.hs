module CalamityCommands.Internal.HList
  ( HList (..)
  , hmap
  , CheckInfo
  , CheckTypes
  , ParentTypes
  ) where

data HList (f :: * -> *) (ts :: [*]) where
  HNil :: HList f '[]
  HCons :: f t -> HList f ts -> HList f (t ': ts)

hmap :: (forall x. f x -> b) -> HList f ts -> [b]
hmap f = go
  where 
    go HNil = []
    go (HCons ft hxs) = f ft : hmap f hxs

type CheckInfo = '( '[*], '[ '[*]])

type family CheckTypes chks where
  CheckTypes '(x, _) = x

type family ParentTypes chks where
  ParentTypes '(_, '[]) = '( '[], '[])
  ParentTypes '(_, x ': xs) = '( x, xs)
