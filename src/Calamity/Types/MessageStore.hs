-- | A thing for storing the last N messages

module Calamity.Types.MessageStore
  ( MessageStore(..)
  , addMessage
  , getMessage
  , dropMessage
  )
where


import           Data.Default
import qualified Data.PQueue.Prio.Min          as PQ
import           Data.PQueue.Prio.Min           ( MinPQueue )

import           Calamity.Types.General         ( Message )
import           Calamity.Types.Snowflake


data MessageStore = MessageStore
  { messages :: MinPQueue (Snowflake Message) Message
  , limit :: Int
  } deriving (Show, Generic)


instance Default MessageStore where
  def = MessageStore PQ.empty 1000


addMessage :: Message -> MessageStore -> MessageStore
addMessage m s@MessageStore { messages, limit } = s
  { messages = messages
    & PQ.insert (getID m) m
    & PQ.drop (min 0 (PQ.size messages - limit))
  }

getMessage :: Snowflake Message -> MessageStore -> Maybe Message
getMessage id MessageStore { messages } = messages
  & PQ.assocsU
  & find (\(k, _) -> k == id)
  & fmap snd

dropMessage :: Snowflake Message -> MessageStore -> MessageStore
dropMessage id s@MessageStore { messages } =
  s { messages = PQ.filterWithKey (\k _ -> k /= id) messages }
