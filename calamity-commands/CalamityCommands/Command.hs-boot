{-# LANGUAGE PolyKinds #-}

-- | Commands and stuff
module CalamityCommands.Command
    ( Command
    ) where

import TextShow
import Data.Kind (Type)

type role Command representational representational phantom nominal
data Command (m :: Type -> Type) (c :: Type) (chks :: '( '[Type], '[ '[Type]])) (a :: Type)

-- instance Show (Command m c a)
-- instance TextShow (Command m c a)
