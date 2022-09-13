This document describes the server messages sent as part of the room setup within select_screen in the case of online multiplayer starting with joining a room.

The messages to send and receive differ depending on whether the person in the room takes the role of a player or a spectator.

In general the process while in the select screen is always as follows:

1. Upon entering the room, the server sends a message that assigns ids to both players and makes the current menu state of both players known.

2. Every time the player move / adjust their settings they send their current menu state to the server.

3. The server sends out the updated menu state to everyone else in the room.

Step 2 and 3 repeat until both players have readied up and the game starts.

During the game, inputs are being forwarded by the server.

As the game ends the server sends one message to announce the new win count followed by a new message recreating the select screen and updating ratings.

# Examples

## Server messages received and sent as a player

### Server messages a player upon initial creation of a room
```json
{
    "a_menu_state": {
        "cursor": "__Ready",
        "panels_dir": "pdp_ta_common",
        "character": "pa_characters_poochy",
        "stage": "pa_stages_flower",
        "character_display_name": "Poochy",
        "ranked": true,
        "level": 10
    },
    "b_menu_state": {
        "character_is_random": "__RandomCharacter",
        "stage_is_random": "__RandomStage",
        "character_display_name": "",
        "cursor": "__Ready",
        "panels_dir": "panelhd_basic_mizunoketsuban",
        "ranked": true,
        "stage": "__RandomStage",
        "character": "__RandomCharacter",
        "level": 5
    },
    "create_room": true,
    "your_player_number": 2,
    "op_player_number": 1,
    "ratings": [{
            "new": 1391,
            "league": "Silver",
            "old": 1391,
            "difference": 0
        }, {
            "league": "Newcomer",
            "placement_match_progress": "0/30 placement matches played.",
            "new": 0,
            "old": 0,
            "difference": 0
        }
    ],
    "opponent": "oh69fermerchan",
    "rating_updates": true
}
```
Entering the select screen is always initiated by receiving a message by the server containing the property `"create_room" = true`.
As a player, the server assigns the own player id to use `your_player_number` as well as that of the opponent `op_player_number`.
By convention the information inside `a_menu_state` belongs to the player with the id `1` and respectively `b_menu_state` to the player with id `2`.

### Player messages server upon moving their cursor or changing their selection

```json
{
    "character_is_random": "__RandomCharacter",
    "stage_is_random": "__RandomStage",
    "character_display_name": "Dragon",
    "cursor": "__Ready",
    "ready": true,
    "level": 5,
    "wants_ready": true,
    "ranked": true,
    "panels_dir": "panelhd_basic_mizunoketsuban",
    "character": "pa_characters_dragon",
    "stage": "pa_stages_wind",
    "loaded": true
}
```

Locally comparing for differences with the previous menu state, the client always sends this message to the server upon every move the player does.

#### Random values

Historically there have been various developments that *specifically* led to different interpretations of the fields `character_is_random` and `stage_is_random` over time:

Originally these used to be boolean values to indicate whether the player chose the random option. With the addition of bundle characters, this value was transformed into a `string`. The values held by this would be either:
- the id if a bundle character/stage was picked
- a special string value if the random character/stage option was picked
- `nil` if a non-bundle and non-random selection was made

In the newest iteration, the game no longer sends the special string value for random character/stage but instead sends the character/stage locally picked from the roll in the `character` or `stage` field while sending the random field as `nil`.

Ultimately, the `random` fields serve as the indicators to decide whether the local client has randomization to do for picking mods upon receiving the message.

### Server messages player and spectators about changes in menu state

```json
{
    "menu_state": {
        "character": "pa_characters_poochy",
        "character_display_name": "Poochy",
        "loaded": true,
        "cursor": "__Ready",
        "panels_dir": "pdp_ta_common",
        "ranked": true,
        "stage": "pa_stages_flower",
        "wants_ready": false,
        "level": 10
    }
}
```
In essence this is simply the server forwarding the message sent by the clients to the server upon interaction. In case random options are not selected such as here the server omits this information.
This message assumes that there cannot be more than 2 players in a room, meaning the client has to apply any such messages to the local settings belonging to `op_player_number`.
Additionally upon each received message the server typically sends out a message about the current ranked status:

```json
{
    "ranked_match_denied": true,
    "reasons": ["Levels don't match"]
}
```
or respectively the approval with the flag `ranked_match_approved`.

### Game start as player

To be added (likely identical to spectator)

### Game end as player

To be added (likely identical to spectator)

## Server messages received as a spectator

### Server messages a spectator that joins during character select

```json
{
    "ranked": false,
    "a_menu_state": {
        "ranked": false,
        "panels_dir": "pdp_ta_common",
        "character": "pa_characters_froggy",
        "cursor": "__Ready",
        "level": 5,
        "character_display_name": "Froggy",
        "stage": "pa_stages_flower",
        "ready": true
    },
    "b_menu_state": {
        "ranked": true,
        "panels_dir": "panelhd_basic_mizunoketsuban",
        "character": "pa_characters_yoshi",
        "cursor": "__Ready",
        "level": 5,
        "character_display_name": "Yoshi",
        "stage": "pa_stages_fire",
        "ready": false
    },
    "stage": "pa_stages_flower",
    "spectate_request_granted": true,
    "ratings": [{
            "new": 0,
            "old": 0,
            "difference": 0,
            "league": "Newcomer",
            "placement_match_progress": "0/30 placement matches played."
        }, {
            "new": 0,
            "old": 0,
            "difference": 0,
            "league": "Newcomer",
            "placement_match_progress": "0/30 placement matches played."
        }
    ],
    "player_settings": {
        "level": 5,
        "character_display_name": "Froggy",
        "character": "pa_characters_froggy",
        "player_number": 1
    },
    "rating_updates": true,
    "spectate_request_rejected": false,
    "win_counts": [1, 11],
    "match_start": false,
    "opponent_settings": {
        "level": 5,
        "character_display_name": "Yoshi",
        "character": "pa_characters_yoshi",
        "player_number": 2
    }
}
```

Spectators don't get their own id and instead they get the information about both players served comprehensively in the extra arrays `player_settings` and `opponent_settings`.
Furthermore some information like the ranked status, the selected stage is preprocessed and does not need to be figured out client side anymore.
The initial message for joining as a spectator is marked with the `"spectate_request_granted": true,` flag and lacks the `create_room` flag as the room has already been created previously by the players.

### Joining a match in progress as a spectator

```json
{
    "rating_updates": true,
    "opponent_settings": {
        "player_number": 2,
        "character_display_name": "Bumpty",
        "level": 8,
        "character": "pa_characters_bumpty"
    },
    "spectate_request_granted": true,
    "match_start": false,
    "a_menu_state": {
        "cursor": "__Ready",
        "character_display_name": "Blargg",
        "level": 8,
        "ready": true,
        "panels_dir": "panelhd_basic_mizunoketsuban",
        "ranked": false,
        "character": "pa_characters_blargg",
        "stage": "pa_stages_fire"
    },
    "b_menu_state": {
        "cursor": "__Ready",
        "character_display_name": "Bumpty",
        "level": 8,
        "ready": true,
        "panels_dir": "pdp_ta_common",
        "ranked": false,
        "character": "pa_characters_bumpty",
        "stage": "pa_stages_sea"
    },
    "stage": "pa_stages_fire",
    "ratings": [{
            "league": "Newcomer",
            "difference": 0,
            "new": 0,
            "old": 0,
            "placement_match_progress": "1/30 placement matches played."
        }, {
            "old": 1168,
            "difference": 0,
            "placement_matches_played": 78,
            "league": "Bronze",
            "new": 1168
        }
    ],
    "win_counts": [7, 4],
    "player_settings": {
        "player_number": 1,
        "character_display_name": "Blargg",
        "level": 8,
        "character": "pa_characters_blargg"
    },
    "ranked": false,
    "replay_of_match_so_far": {
        "vs": {
            "P2_level": 8,
            "P2_name": "kornflakes_apk",
            "P2_char": "pa_characters_bumpty",
            "seed": 343818,
            "P1_level": 8,
            "in_buf": "omitted for brevity, in_buf contains encoded inputs for P1",
            "I": "omitted for brevity, I contains encoded inputs for P2",
            "Q": "",
            "R": "",
            "do_countdown": true,
            "ranked": false,
            "P": "",
            "O": "",
            "P1_name": "fightmeyoucoward",
            "P1_char": "pa_characters_blargg"
        }
    },
    "spectate_request_rejected": false
}
```

This is largely the same joining within character select with the addition of `"replay_of_match_so_far"` containing the information about the match until the point of joining.


### Game end as spectator

First the server announces the win counts
```json
{
    "win_counts": [22, 8]
}
```

Followed by a `create_room` message

```json
{
    "rating_updates": true,
    "ratings": [{
            "league": "Newcomer",
            "placement_match_progress": "1/30 placement matches played.",
            "old": 0,
            "difference": 0,
            "new": 0
        }, {
            "league": "Bronze",
            "placement_matches_played": 78,
            "old": 1168,
            "difference": 0,
            "new": 1168
        }
    ],
    "a_menu_state": {
        "ranked": false,
        "character": "pa_characters_blargg",
        "stage": "pa_stages_fire",
        "panels_dir": "panelhd_basic_mizunoketsuban",
        "character_display_name": "Blargg",
        "level": 8,
        "cursor": "__Ready",
        "ready": false
    },
    "create_room": true,
    "b_menu_state": {
        "ranked": false,
        "character": "pa_characters_bumpty",
        "stage": "pa_stages_sea",
        "panels_dir": "pdp_ta_common",
        "character_display_name": "Bumpty",
        "level": 8,
        "cursor": "__Ready",
        "ready": false
    },
    "character_select": true
}
```

It is worth mentioning that unlike for joining the room, the spectator no longer gets to enjoy preprocessed information like `player_settings`, those are exclusive to first joining the room.
Additionally a `character_select` flag is given although at the moment this is redundant with the `create_room` flag for all purposes.

### Receiving updates in character select as spectator

```json
{
    "menu_state": {
        "ranked": false,
        "character": "pa_characters_bumpty",
        "stage": "pa_stages_sea",
        "panels_dir": "pdp_ta_common",
        "ready": true,
        "character_display_name": "Bumpty",
        "loaded": true,
        "level": 8,
        "cursor": "__Ready",
        "wants_ready": true
    },
    "player_number": 2
}
```

Unlike the player, the spectator receives the menu state flavored with the room specific id of the player that interacted with the select screen as they otherwise wouldn't know which player moved.


### Game start as spectator

```json
{
    "ranked": false,
    "opponent_settings": {
        "character_display_name": "Bumpty",
        "player_number": 2,
        "level": 8,
        "panels_dir": "pdp_ta_common",
        "character": "pa_characters_bumpty"
    },
    "stage": "pa_stages_fire",
    "player_settings": {
        "character_display_name": "Blargg",
        "player_number": 1,
        "level": 8,
        "panels_dir": "panelhd_basic_mizunoketsuban",
        "character": "pa_characters_blargg"
    },
    "seed": 3245472,
    "match_start": true
}
```

Identified by the `match_start` flag, this message only contains the final settings used for the match in the same format as already known when joining the match as a spectator.
This message should be identical to the one the players receive.
