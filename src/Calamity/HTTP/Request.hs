-- | Generic Request type

module Calamity.HTTP.Request where

import           Data.Aeson              hiding ( Options )
import qualified Data.ByteString.Lazy          as LB
import           Data.String                    ( String )
import           Data.Text.Strict.Lens
import           Network.Wreq

import           Calamity.Client.Types
import           Calamity.HTTP.Ratelimit
import           Calamity.HTTP.Route
import           Calamity.HTTP.Types
import           Calamity.Types.General


fromResult :: Monad m => Result a -> ExceptT RestError m a
fromResult (Success a) = pure a
fromResult (Error   e) = throwE (DecodeError $ e ^. packed)

extractRight :: Monad m => Either a b -> ExceptT a m b
extractRight (Left  a) = throwE a
extractRight (Right a) = pure a


class Request a r | a -> r where
  toRoute :: a -> Route

  url :: a -> String
  url r = path (toRoute r) ^. unpacked

  toAction :: a -> Options -> IO (Response LB.ByteString)

  -- TODO: instead of using BotM, instead use a generic HasRatelimits monad
  -- so that we can make requests from shards too

  invokeRequest :: FromJSON r => a -> EventM (Either RestError r)
  invokeRequest r = runExceptT inner
    where inner :: ExceptT RestError EventM r
          inner = do
            rlState' <- asks rlState
            token' <- asks token

            resp <- scope ("[Request Route: "+|toRoute r ^. #path|+"]") $ doRequest rlState' (toRoute r) (toAction r $ requestOptions token')

            resp' <- extractRight resp

            fromResult . fromJSON $ resp'

defaultRequestOptions :: Options
defaultRequestOptions =
  defaults
    & header "User-Agent" .~ [ "Calamity (https://github.com/nitros12/yet-another-haskell-discord-library)" ]
    & checkResponse
    ?~ (\_ _ -> pure ())


requestOptions :: Token -> Options
requestOptions t =
  defaultRequestOptions & header "Authorization" .~ [encodeUtf8 $ formatToken t]
