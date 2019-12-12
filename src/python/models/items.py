import asyncio
import re
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Type, Union
from uuid import UUID

import lxml  # nosec

import nio

from ..html_filter import HTML_FILTER
from ..utils import AutoStrEnum, auto
from .model_item import ModelItem

OptionalExceptionType = Union[Type[None], Type[Exception]]


@dataclass
class Account(ModelItem):
    user_id:         str                = field()
    display_name:    str                = ""
    avatar_url:      str                = ""
    first_sync_done: bool               = False
    profile_updated: Optional[datetime] = None

    def __lt__(self, other: "Account") -> bool:
        name       = self.display_name or self.user_id[1:]
        other_name = other.display_name or other.user_id[1:]
        return name < other_name

    @property
    def filter_string(self) -> str:
        return self.display_name


@dataclass
class Room(ModelItem):
    room_id:        str       = field()
    display_name:   str       = ""
    avatar_url:     str       = ""
    topic:          str       = ""
    inviter_id:     str       = ""
    inviter_name:   str       = ""
    inviter_avatar: str       = ""
    left:           bool      = False
    typing_members: List[str] = field(default_factory=list)

    can_invite:        bool = True
    can_send_messages: bool = True

    # Event.serialized
    last_event: Optional[Dict[str, Any]] = field(default=None, repr=False)

    def __lt__(self, other: "Room") -> bool:
        # Order: Invited rooms > joined rooms > left rooms.
        # Within these categories, sort by date then by name.
        # Left rooms may still have an inviter_id, so check left first.
        return (
            self.left,

            other.inviter_id,

            other.last_event["date"] if other.last_event else
            datetime.fromtimestamp(0),

            self.display_name.lower() or self.room_id,
        ) < (
            other.left,

            self.inviter_id,

            self.last_event["date"] if self.last_event else
            datetime.fromtimestamp(0),

            other.display_name.lower() or other.room_id,
        )

    @property
    def filter_string(self) -> str:
        return " ".join((
            self.display_name,
            self.topic,
            re.sub(r"<.*?>", "", self.last_event["inline_content"])
            if self.last_event else "",
        ))


@dataclass
class Member(ModelItem):
    user_id:      str  = field()
    display_name: str  = ""
    avatar_url:   str  = ""
    typing:       bool = False
    power_level:  int  = 0
    invited:      bool = False

    def __lt__(self, other: "Member") -> bool:
        # Sort by name, but have members with higher power-level first and
        # invited-but-not-joined members last
        name       = (self.display_name or self.user_id[1:]).lower()
        other_name = (other.display_name or other.user_id[1:]).lower()

        return (
            self.invited, other.power_level, name,
        ) < (
            other.invited, self.power_level, other_name,
        )


    @property
    def filter_string(self) -> str:
        return self.display_name


class UploadStatus(AutoStrEnum):
    Uploading = auto()
    Caching   = auto()
    Error     = auto()


@dataclass
class Upload(ModelItem):
    uuid:     UUID                = field()
    task:     asyncio.Task        = field()
    monitor:  nio.TransferMonitor = field()
    filepath: Path                = field()

    total_size: int                 = 0
    uploaded:   int                 = 0
    speed:      float               = 0
    time_left:  Optional[timedelta] = None

    status:     UploadStatus          = UploadStatus.Uploading
    error:      OptionalExceptionType = type(None)
    error_args: Tuple[Any, ...]       = ()

    start_date: datetime = field(init=False, default_factory=datetime.now)


    def __lt__(self, other: "Upload") -> bool:
        # Sort from newest upload to oldest.
        return self.start_date > other.start_date


class TypeSpecifier(AutoStrEnum):
    none              = auto()
    profile_change    = auto()
    membership_change = auto()


@dataclass
class Event(ModelItem):
    source:        Optional[nio.Event] = field()
    client_id:     str                 = field()
    event_id:      str                 = field()
    date:          datetime            = field()
    sender_id:     str                 = field()
    sender_name:   str                 = field()
    sender_avatar: str                 = field()

    content:        str = ""
    inline_content: str = ""

    type_specifier: TypeSpecifier = TypeSpecifier.none

    target_id:     str = ""
    target_name:   str = ""
    target_avatar: str = ""

    is_local_echo:    bool                      = False
    local_event_type: Optional[Type[nio.Event]] = None

    media_url:        str            = ""
    media_title:      str            = ""
    media_width:      int            = 0
    media_height:     int            = 0
    media_duration:   int            = 0
    media_size:       int            = 0
    media_mime:       str            = ""
    media_crypt_dict: Dict[str, Any] = field(default_factory=dict)

    thumbnail_url:        str            = ""
    thumbnail_width:      int            = 0
    thumbnail_height:     int            = 0
    thumbnail_crypt_dict: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.inline_content:
            self.inline_content = HTML_FILTER.filter_inline(self.content)


    def __lt__(self, other: "Event") -> bool:
        # Sort events from newest to oldest. return True means return False.
        return self.date > other.date

    @property
    def event_type(self) -> Type:
        if self.local_event_type:
            return self.local_event_type

        return type(self.source)

    @property
    def links(self) -> List[str]:
        urls: List[str] = []

        if self.content.strip():
            urls += [link[2] for link in lxml.html.iterlinks(self.content)]

        if self.media_url:
            urls.append(self.media_url)

        return urls


@dataclass
class Device(ModelItem):
    device_id:      str  = field()
    ed25519_key:    str  = field()
    trusted:        bool = False
    blacklisted:    bool = False
    display_name:   str  = ""
    last_seen_ip:   str  = ""
    last_seen_date: str  = ""
