{-# LANGUAGE DeriveDataTypeable, GeneralizedNewtypeDeriving, OverloadedStrings #-}
module Web.Campfire.Types where

import Control.Applicative ((<$>), (<*>), pure)
import Control.Monad (mzero)
import Data.Aeson
import qualified Data.Aeson.Types as AT (typeMismatch, Parser(..))
import Data.Attoparsec (parse, maybeResult, eitherResult, Parser(..))
import Data.ByteString as BS (readFile)
import qualified Data.Text as T
import qualified Data.Text.IO as TI
import Data.Time.Clock (UTCTime)
import Data.Time.Format
import qualified Data.Map as M
import Data.Text
import Data.Typeable
import Locale (defaultTimeLocale)

---------- Rooms
data Room = Room { roomId               :: Id, -- I sure don't like this solution
                   roomName             :: T.Text,
                   roomTopic            :: Maybe T.Text,
                   roomMembershipLimit  :: Integer,
                   roomFull             :: Maybe Bool,
                   roomOpenToGuests     :: Maybe Bool,
                   roomActiveTokenValue :: Maybe T.Text,
                   roomUpdatedAt        :: CampfireTime,
                   roomCreatedAt        :: CampfireTime,
                   roomUsers            :: Maybe [User] } deriving (Show)

 -- There is probably a better way to do this
 --TODO: need to pull the room out of the root object
instance FromJSON Room where
  parseJSON (Object v) = Room <$> v .:| ("id", 0)
                              <*> v .:  "name"
                              <*> v .:  "topic"
                              <*> v .:  "membership_limit"
                              <*> v .:? "full"
                              <*> v .:? "open_to_guests"
                              <*> v .:? "active_token_value"
                              <*> v .:  "updated_at"
                              <*> v .:  "created_at"
                              <*> v .:? "users"
  parseJSON _ = mzero

newtype RoomWithRoot = RoomWithRoot { unRootRoom :: Room } deriving (Show)

instance FromJSON RoomWithRoot where
  parseJSON (Object v) = RoomWithRoot <$> v .: "room"
  parseJSON _          = mzero


newtype Rooms = Rooms { unRooms :: [Room] } deriving (Show)

instance FromJSON Rooms where
  parseJSON (Object v) = Rooms <$> v .: "rooms"
  parseJSON _          = mzero

---------- Messages
data Message = Message { messageId        :: Id,
                         messageBody      :: T.Text,
                         messageRoomId    :: Id,
                         messageUserId    :: T.Text,
                         messageCreatedAt :: CampfireTime,
                         messageType      :: MessageType }

instance FromJSON Message where
  -- consider using an ADT for type
  parseJSON (Object v) = Message <$> v .: "id"
                                 <*> v .: "body"
                                 <*> v .: "room_id"
                                 <*> v .: "user_id"
                                 <*> v .: "created_at"
                                 <*> v .: "type"
  parseJSON _          = mzero

newtype Messages = Messages { unMessages :: [Room] } deriving (Show)

instance FromJSON Messages where
  parseJSON (Object v) = Messages <$> v .: "messages"
  parseJSON _          = mzero


data MessageType = TextMessage |
                   PasteMessage |
                   SoundMessage |
                   AdvertisementMessage |
                   AllowGuestsMessage |
                   DisallowGuestsMessage |
                   IdleMessage |
                   KickMessage |
                   LeaveMessage |
                   SystemMessage |
                   TimestampMessage |
                   TopicChangeMessage |
                   UnidleMessage |
                   UnlockMessage |
                   UploadMessage
                   deriving (Eq, Ord, Read, Show, Typeable)

instance FromJSON MessageType where
  parseJSON (String v) = case unpack v of
                           "TextMessage"           -> pure TextMessage
                           "PasteMessage"          -> pure PasteMessage
                           "SoundMessage"          -> pure SoundMessage
                           "AdvertisementMessage"  -> pure AdvertisementMessage
                           "AllowGuestsMessage"    -> pure AllowGuestsMessage
                           "DisallowGuestsMessage" -> pure DisallowGuestsMessage
                           "IdleMessage"           -> pure IdleMessage
                           "KickMessage"           -> pure KickMessage
                           "LeaveMessage"          -> pure LeaveMessage
                           "SystemMessage"         -> pure SystemMessage
                           "TimestampMessage"      -> pure TimestampMessage
                           "TopicChangeMessage"    -> pure TopicChangeMessage
                           "UnidleMessage"         -> pure UnidleMessage
                           "UnlockMessage"         -> pure UnlockMessage
                           "UploadMessage"         -> pure UploadMessage
                           _                       -> mzero
  parseJSON _          = mzero

---------- Statements
-- Statements are messages that you can send to CampFire
data Statement = TextStatement { statementBody :: T.Text } |
                 PasteStatement { statementBody :: T.Text} |
                 SoundStatement { soundType :: Sound     } |
                 TweetStatement { statementUrl  :: T.Text}
                 deriving (Eq, Ord, Read, Show, Typeable)

instance ToJSON Statement where
  toJSON TextStatement  { statementBody = b} =
    object ["type" .= ("TextMessage" :: T.Text), "body" .= b]
  toJSON PasteStatement { statementBody = b} =
    object ["type" .= ("PasteMessage" :: T.Text), "body" .= b]
  toJSON SoundStatement { soundType = t    } =
    object ["type" .= ("SoundMessage" :: T.Text), "body" .= t]
  toJSON TweetStatement { statementUrl = u } =
    object ["type" .= ("TweetStatemetn" :: T.Text), "body" .= u]


data Sound = Rimshot |
             Crickets |
             Trombone
             deriving (Eq, Ord, Read, Show, Typeable)

instance ToJSON Sound where
  toJSON Rimshot  = String "rimshot"
  toJSON Crickets = String "crickets"
  toJSON Trombone = String "trombone"


---------- Users
data User = User { userId           :: Id,
                   userName         :: T.Text,
                   userEmailAddress :: T.Text,
                   userAdmin        :: Bool,
                   userCreatedAt    :: CampfireTime,
                   userType         :: UserType } 
            deriving (Eq, Ord, Read, Show, Typeable)

instance FromJSON User where
  -- consider using an ADT for type
  parseJSON (Object v) = User <$> v .: "id"
                              <*> v .: "name"
                              <*> v .: "email_address"
                              <*> v .: "admin"
                              <*> v .: "created_at"
                              <*> v .: "type"
  parseJSON _          = mzero

newtype UserWithRoot = UserWithRoot { unRootUser :: User } deriving (Show)

instance FromJSON UserWithRoot where
  parseJSON (Object v) = UserWithRoot <$> v .: "user"
  parseJSON _          = mzero

data UserType = Member | 
                Guest
                deriving (Eq, Ord, Read, Show, Typeable)

instance FromJSON UserType where
  parseJSON (String v) = case unpack v of
                           "Member" -> pure Member
                           "Guest"  -> pure Guest
                           _        -> mzero
  parseJSON _          = mzero

---------- Uploads
data Upload = Upload { uploadId          :: Id,
                       uploadName        :: T.Text,
                       uploadRoomId      :: Id,
                       uploadUserId      :: Id,
                       uploadByteSize    :: Integer,
                       uploadContentType :: T.Text,
                       uploadFullUrl     :: T.Text,
                       uploadCreatedAt   :: CampfireTime }
              deriving (Eq, Ord, Read, Show, Typeable)

instance FromJSON Upload  where
  -- consider using an ADT for type
  parseJSON (Object v) = Upload <$> v .: "id"
                                <*> v .: "name"
                                <*> v .: "room_id"
                                <*> v .: "user_id"
                                <*> v .: "byte_size"
                                <*> v .: "content_type"
                                <*> v .: "full_url"
                                <*> v .: "created_at"
  parseJSON _          = mzero

---------- General Purpose Types
type Id = Integer

newtype CampfireTime = CampfireTime { 
                         fromCampfireTime :: UTCTime 
                       } deriving (Eq, Ord, Read, Show, Typeable, FormatTime)

instance FromJSON CampfireTime where
  parseJSON (String t) = case parseTime defaultTimeLocale "%Y/%m/%d %T %z" (unpack t) of
                           Just d -> pure (CampfireTime d)
                           _      -> fail "Could not parse Campfire-formatted time"
  parseJSON v          = AT.typeMismatch "CampfireTime" v

-- Helpers
(.:|) :: (FromJSON a) => Object -> (Text, a) -> AT.Parser a
obj .:| (key, d) = case M.lookup key obj of
                        Nothing -> pure d
                        Just v  -> parseJSON v
