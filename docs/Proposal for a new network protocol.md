# Proposal for a new network protocol

This is mostly about the subprotocol used in json messages ("J") for setting up matches, login, taunt and spectating and to some extent player inputs ("I", "U").  

## Why the current protocol should go

The current protocol is dated and confusing in some ways.  
It makes some strong assumptions about how matches are setup, effectively impeding the creation of a variety of online functions by being convoluted and so rigid that almost any change in the protocol immediately breaks version compatibility between stable and beta.  
I'll try to illustrate the problems a bit further while mentioning which boxes a new network protocol should tick in order to do well enough for the long haul.  

### Strong assumptions about player count

In the current network protocol, every match is a two-player match.  
This is immediately obvious by the choice of field names such as "player_settings" and "opponent_settings", as well as implicit assumptions that any incoming menu state or input can only be from one sender, the opponent.  

A new network protocol should make no assumptions about an exact player count.  
A new network protocol should clearly state the source of player settings or inputs, ideally via their public player id so that clients do not have to juggle the server's number assignments with its own display order.

### Different names for the same things

In the current protocol, the same data or subsets of that data are sent under different names.  
Namely, generic `menu_state`, menu state without being declared as such, `a_menu_state` or `b_menu_state` when used for a certain player, `player_settings` or `opponent_settings` as a subset of a player's menu state at game start.  

A new protocol should aim to clearly separate player settings and their cursor activity.  
A new protocol should have only one header for each group of settings and each group of settings should always cover the complete set of its values.  

### Imprecise level information 

Level data is currently encapsulated inside the level number.  
This shuts down any possible customization to play online without altering the standard levels.  
Additionally it means there way to play online using classic mode difficulties.  

A new protocol should send the complete frame data for the player stack based on their selection to create forward compatibility for customizations. The level should still be sent for display purposes unless the level data comes from classic mode.

### Replay information is not represented in a sensible hierarchy

Aside from also being guilty of player count issues, replay data presents player related data on the same hierarchy as player-specific data.  
Specifically, data like `seed`, `countdown` and `ranked` is recorded on the same level as player replay data, levels and characters.

A new protocol should aim to clearly separate player-related data and general game data not specific to the player.  
Specifically, general game data could be recorded on the same level as the game mode ("vs", "time" etc).  
Personal comment: We could still assign this data in the previous hierarchy for saving replays to maintain compatibility. But I think it would be better to overhaul that alongside it, introduce an official v2 and have a legacy replay loader in a separate file.

### There is only vs right?

Any online gameplay is implicitly assumed to be vs.  

In a new network protocol, server rooms should have a field that holds the game mode information and send it to new spectators.  
A new network protocol should implement a change request for the game mode that is granted upon agreement of both players.  
This way, rooms could be default vs but subject to change *or* upon accepting a challenge, players have to agree on a game mode on room creation.


## What the new protocol should enable long-term

Here I'm going to name a couple of concrete changes, also in client design, that should impact how we design the new network protocol.  
Additionally I'll name some issues that are currently blocked by the network protocol or would require the current network protocol to change or extend. Ideally we can cover as many of these in advance to greatly reduce the amount of future breaking changes beyond this one.

### Extending online to outside the lobby

Regardless of the exact client-side implementation, players having a way to be online without being in lobby has to be one of the core goals of a new network protocol.  
With players being online in 1p modes or possibly by default, it does no longer make sense to send player settings on login as they will constantly changed.  
Player settings should only be sent when a challenge is issued to another player or when the server requests those settings to satisfy a spectate request.  

To sum up:  
Players should be able to log in only with their name + id.  
Players should be able to inform the client about what they are currently doing ingame.  
Name changes should be verifiable against the server directly rather than on login.

### Offer 1p modes as parallel play

https://github.com/panel-attack/panel-attack/issues/688  

Accomodating different game modes in server rooms allows the game mode to be selected.  
Any remaining items would be relativly trivial to implement.

### Time Attack vs

https://github.com/panel-attack/panel-attack/issues/587  

Accurate level data being sent enables classic mode selection on the client.  
Accomodating different game modes in server rooms allows the game mode to be selected.  
Any remaining items would be relatively trivial to implement once those two are cleared via a new network protocol.

### More than 2 players vs

https://github.com/panel-attack/panel-attack/issues/254  

Still not trivial but an extendable network protocol that already accomodates n players with inputs and states being identifiable by public player id would still cover a substantial amount of work for this feature.


## Proposal

With the introduction part out of the way, I'll try to do a take that hopefully satisfies everything above.  
Please don't hesitate to call out any oversights on my end.  

### Login

Use case: Logging in on the ranked server after establishing a connection

#### Client request

```Json
{
    "loginRequest":
    {
        "userId": 123456789,
        "name": "notDefaultName"
        "saveReplaysPublicly": true
    }
}
```

#### Server responses

If approved, the server responds with the player's public id
```Json
{
    "loginResponse":
    {
        "approved": true,
        "publicId": 42424242
    }
}
```

if denied

```Json
{
    "loginResponse":
    {
        "approved": false,
        "reason": "someReason"
    }
}
```

if denied and banned

```Json
{
    "loginResponse":
    {
        "approved": false,
        "reason": "someReason",
        "banDuration": 1000
    }
}
```

### Change name

Use case: Changing your name while online

#### Client request

```Json
{
    "nameChangeRequest":
    {
        "name": "notDefaultName"
    }
}
```

#### Server responses

If approved
```Json
{
    "nameChangeResponse":
    {
        "approved": true
    }
}
```

if denied

```Json
{
    "nameChangeResponse":
    {
        "approved": false,
        "reason": "someReason"
    }
}
```

### Update replay saving setting

Use case: Reconfigure your setting for whether replays should be saved publicly while online.

#### Client request

```Json
{
    "saveReplaysPublicly": true
}
```

### Online Players

Use case: Requesting online data about players (e.g. for a menu displaying all players online)

#### Client request

```Json
{
    "getOnlineData": "players"
}
```

#### Server response

```Json
{
    // public player id as the key
    "42424242": 
    {
        "name": "someName",
        // possible activities: afk, idle, spectating, playing
        "activity": "idle",
        "rating": 1337
    },
    "53535353": 
    {
        "name": "someOtherName",
        "activity": "playing",
        "room": 34,
        "rating": 0,
        "placementMatchesPlayed": 14
    },
    "64646464": 
    {
        "name": "blablabla",
        "activity": "playing",
        "room": 34,
        "rating": 1508
    },
    "75757575": 
    {
        "name": "someSpectator",
        "activity": "spectating",
        "rating": 2024,
        "room": 34
    },
    "86868686": 
    {
        "name": "some1pModePlayer",
        "activity": "playing",
        "gameMode": "training",
        "rating": 809
    }
}
```

### Online rooms

Use case: Requesting online data about rooms (e.g. for a menu displaying all rooms online aka Lobby)

#### Client request

```Json
{
    "getOnlineData": "rooms"
}
```

#### Server response

```Json
{
    // room number as the key
    "34":
    {
        "players":
        {
            "53535353":
            {
                "name": "someOtherName",
                "rating": 0,
                "winCount": 7
            },
            "64646464":
            {
                "name": "blablabla",
                "rating": 1508,
                "winCount": 4
            }
        },
        "spectators":
        {
            "75757575":
            {
                "name": "someSpectator",
                "rating": 2024
            }
        }
    }
}
```

### Update activity

#### Client request

```Json
{
    "updateActivity":
    {
        "activity": "playing",
        "gameMode": "time"
    }
}
```

### Challenge a player

Use case: Challenging a player that is not currently playing in a multiplayer room.  
Example: Player 42424242 challenges player 75757575.

#### Client request

```Json
{
    "sendChallenge":
    {
        "playerId": 75757575
    }
}
```

#### Server challenge forwarding

```Json
{
    "challengeSent":
    {
        "player":
        {
            "id": 42424242,
            "name": "someName",
            "rating": 1337
        }
    }
}
```

### Reject a challenge

Use case: Rejecting a challenge from another player.  
Example: Player 75757575 rejects the challenge by player 42424242.

#### Client request

```Json
{
    "rejectChallenge":
    {
        "id": 42424242
    }
}
```

#### Server forwarding rejection

sending to 42424242
```Json
{
    "challengeRejected":
    {
        "id": 75757575
    }
}
```

### Withdraw challenge

Use case: Withdrawing a challenge you issued to another player (currently you have to disconnect for that).  
Example: Player 42424242 withdraws their challenge to player 75757575

#### Client request

```Json
{
    "withdrawChallenge":
    {
        "id": 75757575
    }
}
```

#### Server forwarding 

```Json
{
    "challengeWithdrawn":
    {
        "id": 42424242
    }
}
```

### Accept a challenge

Use case: Accepting another player's challenge.  
Example: Player 75757575 accepts player 42424242's challenge.

#### Client request

```Json
{
    "acceptChallenge":
    {
        "playerId": 42424242
    }
}
```

#### Server response

Verifies that both players aren't players in a room.  
Creates a room and adds the two players

```Json
{
    "createRoom":
    {
        "roomSettings":
        {
            "gameMode": "vs",
            "playerCount": 2
        },
        "players": 
        {
            "42424242":
            {
                "name": "someName",
                "rating":
                {
                    "league": "Silver",
                    "new": 1337,
                    "old": 1337,
                    "difference": 0
                },
                "winCount": 0
            },
            "75757575":
            {
                "name": "someSpectator",
                "rating":
                {
                    "league": "Master",
                    "new": 2024,
                    "old": 2024,
                    "difference": 0
                },
                "winCount": 0
            }
        }
    }
}
```

### Update settings

In response to receiving the `createRoom` message, clients should directly send a first update with their current settings to the server.  
The message is sent again every time the settings are changed.

#### Client response

In response to the room creation, both clients send their current settings to the server.  
Example for player 42424242 here.

```Json
{
    "update":
    {
        "settings":
        {
            "character": "magellan",
            "stage": "flying_airship",
            "panels": "pacci",
            "wantsRanked": false,
            "level": 1,
            "levelData": 
            {
                "startingSpeed": 1,
                "speedIncreaseMode": 1,
                "shockFrequency": 12,
                "shockCap": 21,
                "colors": 5,
                "maxHealth": 121,
                "stop": {
                    "formula": 1,
                    "comboConstant": -20,
                    "chainConstant": 80,
                    "dangerConstant": 160,
                    "coefficient": 20,
                },
                "frameConstants": {
                    "HOVER": 12,
                    "GARBAGE_HOVER": 41,
                    "FLASH": 44,
                    "FACE": 20,
                    "POP": 9
                }
            }
        }
    }
}
```

#### Server forwarding of settings

Sending the settings to player 75757575

```Json
{
    "update":
    {
        "42424242":
        {
            "settings":
            {
                "character": "magellan",
                "stage": "flying_airship",
                "panels": "pacci",
                "wantsRanked": false,
                "level": 1,
                "levelData": 
                {
                    "startingSpeed": 1,
                    "speedIncreaseMode": 1,
                    "shockFrequency": 12,
                    "shockCap": 21,
                    "colors": 5,
                    "maxHealth": 121,
                    "stop": {
                        "formula": 1,
                        "comboConstant": -20,
                        "chainConstant": 80,
                        "dangerConstant": 160,
                        "coefficient": 20,
                    },
                    "frameConstants": {
                        "HOVER": 12,
                        "GARBAGE_HOVER": 41,
                        "FLASH": 44,
                        "FACE": 20,
                        "POP": 9
                    }
                }
            }
        }
    }
}
```

### Update cursor position

In response to receiving the `createRoom` message, clients should directly send a first update with their current cursor positio to the server.  
The message is sent again every time the cursor position changes.  
For general use, I would say `settings` and `cursor` could also be updated in the same message, e.g. when selecting a character updates the character but also moves the cursor to the Ready button in the same step.

#### Client request

```Json
{
    "update":
    {
        "cursor": "Ready"
    }
}
```

#### Server forwarding

```Json
{
    "update":
    {
        "42424242":
        {
            "cursor": "Ready"
        }
    }
}
```

### Update ready+loaded state

#### Client request

```Json
{
    "update":
    {
        "wantsReady": true,
        "loaded": true,
        "ready": true
    }
}
```

#### Server forwarding

```Json
{
    "update":
    {
        "42424242":
        {
            "wantsReady": true,
            "loaded": true,
            "ready": true
        }
    }
}
```

### Update ranked status

When players transmit their wantsRanked setting for the first time and upon changing it, the server sends a message about the current ranked status.  

#### Server message

```Json
{
    "update":
    {
        "ranked": false,
        "rankedReason": ["someName doesn't want ranked","Colors don't match"]
    }
}
```

### Update game mode

Players may choose in some manner to change the game mode. If all players in a room request the same game mode, it is changed.

#### Client request

```Json
{
    "changeGameMode":
    {
        "mode": "time"
    }
}
```

#### Server response

When the all players want the game mode to change, the server confirms with

```Json
{
    "update":
    {
        "gameMode": "time"
    }
}
```


### Game start

When both players are ready, the server sends a game start message.

#### Server message

```Json
{
    "gameStart":
    {
        "roomSettings":
        {
            "seed": 12356789,
            "gameMode": "time",
            "ranked": false,
            "rankedReason": ["someName doesn't want ranked","Colors don't match"],
            "playerCount": 2,
            "selectedStage": "crashing_airship",
        },
        "players":
        {
            "42424242":
            {
                "settings":
                {
                    "character": "magellan",
                    "stage": "flying_airship",
                    "panels": "pacci",
                    "wantsRanked": false,
                    "level": 1,
                    "levelData": 
                    {
                        "startingSpeed": 1,
                        "speedIncreaseMode": 1,
                        "shockFrequency": 12,
                        "shockCap": 21,
                        "colors": 5,
                        "maxHealth": 121,
                        "stop": {
                            "formula": 1,
                            "comboConstant": -20,
                            "chainConstant": 80,
                            "dangerConstant": 160,
                            "coefficient": 20,
                        },
                        "frameConstants": {
                            "HOVER": 12,
                            "GARBAGE_HOVER": 41,
                            "FLASH": 44,
                            "FACE": 20,
                            "POP": 9
                        }
                    }
                }
            },
            "75757575":
            {
                "settings":
                {
                    "character": "megallan",
                    "stage": "crashing_airship",
                    "panels": "pacci",
                    "wantsRanked": true,
                    "level": 1,
                    "levelData": 
                    {
                        "startingSpeed": 1,
                        "speedIncreaseMode": 1,
                        "shockFrequency": 12,
                        "shockCap": 21,
                        "colors": 6,
                        "maxHealth": 121,
                        "stop": {
                            "formula": 1,
                            "comboConstant": -20,
                            "chainConstant": 80,
                            "dangerConstant": 160,
                            "coefficient": 20,
                        },
                        "frameConstants": {
                            "HOVER": 12,
                            "GARBAGE_HOVER": 41,
                            "FLASH": 44,
                            "FACE": 20,
                            "POP": 9
                        }
                    }
                }
            }
        }
    }
}
```

### Game end

The clients report their game result to the server.

#### Client request

```Json
{
    "reportGameResult":
    {
        {
            // records the placement per player in the room
            "75757575": 1,
            "42424242": 2
        }
    }
}
```

### Game results

After receiving the matching game results from the clients, the server updates the room state with the updated win and rating information.

```Json
{
    "update":
    {
        "players": 
        {
            "42424242":
            {
                "rating":
                {
                    "league": "Silver",
                    "new": 1337,
                    "old": 1337,
                    "difference": 0
                },
                "winCount": 0
            },
            "75757575":
            {
                "rating":
                {
                    "league": "Master",
                    "new": 2024,
                    "old": 2024,
                    "difference": 0
                },
                "winCount": 1
            }
        }
    }
}
```

### Spectate request for existing room

Wishing to join a room via the room list.

#### Client request

```Json
{
    "spectateRequest":
    {
        "room": 34
    }
}
```

#### Server response

##### If approved during character select

```Json
{
    "spectateGranted":
    {
        "room": 34,
        "roomSettings":
        {
            "gameMode": "time",
            "ranked": false,
            "rankedReason": ["someName doesn't want ranked","Colors don't match"],
            "playerCount": 2
        },
        "players":
        {
            "42424242":
            {
                "settings":
                {
                    "character": "magellan",
                    "stage": "flying_airship",
                    "panels": "pacci",
                    "wantsRanked": false,
                    "level": 1,
                    "levelData": 
                    {
                        "startingSpeed": 1,
                        "speedIncreaseMode": 1,
                        "shockFrequency": 12,
                        "shockCap": 21,
                        "colors": 5,
                        "maxHealth": 121,
                        "stop": {
                            "formula": 1,
                            "comboConstant": -20,
                            "chainConstant": 80,
                            "dangerConstant": 160,
                            "coefficient": 20,
                        },
                        "frameConstants": {
                            "HOVER": 12,
                            "GARBAGE_HOVER": 41,
                            "FLASH": 44,
                            "FACE": 20,
                            "POP": 9
                        }
                    }
                },
                "rating":
                {
                    "league": "Silver",
                    "new": 1337,
                    "old": 1337,
                    "difference": 0
                },
                "winCount": 0
            },
            "75757575":
            {
                "settings":
                {
                    "character": "megallan",
                    "stage": "crashing_airship",
                    "panels": "pacci",
                    "wantsRanked": true,
                    "level": 1,
                    "levelData": 
                    {
                        "startingSpeed": 1,
                        "speedIncreaseMode": 1,
                        "shockFrequency": 12,
                        "shockCap": 21,
                        "colors": 6,
                        "maxHealth": 121,
                        "stop": {
                            "formula": 1,
                            "comboConstant": -20,
                            "chainConstant": 80,
                            "dangerConstant": 160,
                            "coefficient": 20,
                        },
                        "frameConstants": {
                            "HOVER": 12,
                            "GARBAGE_HOVER": 41,
                            "FLASH": 44,
                            "FACE": 20,
                            "POP": 9
                        }
                    }
                },
                "rating":
                {
                    "league": "Master",
                    "new": 2024,
                    "old": 2024,
                    "difference": 0
                },
                "winCount": 1
            }
        }
    }
}
```

##### if approved during gameplay

```Json
{
    "spectateGranted":
    {
        "room": 34,
        "roomSettings":
        {
            "seed": 12356789,
            "gameMode": "time",
            "ranked": false,
            "rankedReason": ["someName doesn't want ranked","Colors don't match"],
            "selectedStage": "crashing_airship"
        },
        "players":
        {
            "42424242":
            {
                "settings":
                {
                    "character": "magellan",
                    "stage": "flying_airship",
                    "panels": "pacci",
                    "wantsRanked": false,
                    "level": 1,
                    "levelData": 
                    {
                        "startingSpeed": 1,
                        "speedIncreaseMode": 1,
                        "shockFrequency": 12,
                        "shockCap": 21,
                        "colors": 5,
                        "maxHealth": 121,
                        "stop": {
                            "formula": 1,
                            "comboConstant": -20,
                            "chainConstant": 80,
                            "dangerConstant": 160,
                            "coefficient": 20,
                        },
                        "frameConstants": {
                            "HOVER": 12,
                            "GARBAGE_HOVER": 41,
                            "FLASH": 44,
                            "FACE": 20,
                            "POP": 9
                        }
                    }
                },
                "rating":
                {
                    "league": "Silver",
                    "new": 1337,
                    "old": 1337,
                    "difference": 0
                },
                "winCount": 0,
                "inputs": "AAAAAAAAAAAAAAAAAA" // etc
            },
            "75757575":
            {
                "settings":
                {
                    "character": "megallan",
                    "stage": "crashing_airship",
                    "panels": "pacci",
                    "wantsRanked": true,
                    "level": 1,
                    "levelData": 
                    {
                        "startingSpeed": 1,
                        "speedIncreaseMode": 1,
                        "shockFrequency": 12,
                        "shockCap": 21,
                        "colors": 6,
                        "maxHealth": 121,
                        "stop": {
                            "formula": 1,
                            "comboConstant": -20,
                            "chainConstant": 80,
                            "dangerConstant": 160,
                            "coefficient": 20,
                        },
                        "frameConstants": {
                            "HOVER": 12,
                            "GARBAGE_HOVER": 41,
                            "FLASH": 44,
                            "FACE": 20,
                            "POP": 9
                        }
                    }
                },
                "rating":
                {
                    "league": "Master",
                    "new": 2024,
                    "old": 2024,
                    "difference": 0
                },
                "winCount": 0,
                "inputs": "AAAAAAAAAAAAAAAAAA" // etc
            }
        }
    }
}
```

#### Server update for players (and other spectators)

```Json
{
    "update":
    {
        "spectators":
        {
            "96969696":
            {
                "name": "someOtherSpectator",
                "rating": 0
            }
        }
    }
}
```

### Spectate request for 1p mode player

Players may spectate players from the player list, even if not in multiplayer.

#### Client request

```Json
{
    "spectateRequest":
    {
        "player": 86868686
    }
}
```

#### Server response

The server should first check if that player is already in a room and reply with the room variant answer if that is the case.  
If the player is not in a room, create a room, register the requester as spectator and ask the player for their current gameplay data.

```Json
{
    "spectateRequest":
    {
        "player": 07070707,
        "room": 40
    }
}
```

#### Client response

```Json
{
    "spectateGranted":
    {
        "roomSettings":
        {
            "seed": 98765432,
            "gameMode": "training",
            "attackPatterns": "someAttackFileDefinition",
            "selectedStage": "airship_hangar"
        },
        "players":
        {
            "86868686":
            {
                "settings":
                {
                    "character": "madam_q",
                    "stage": "airship_hangar",
                    "panels": "pacci",
                    "level": 1,
                    "levelData": 
                    {
                        "startingSpeed": 1,
                        "speedIncreaseMode": 1,
                        "shockFrequency": 12,
                        "shockCap": 21,
                        "colors": 5,
                        "maxHealth": 121,
                        "stop": {
                            "formula": 1,
                            "comboConstant": -20,
                            "chainConstant": 80,
                            "dangerConstant": 160,
                            "coefficient": 20,
                        },
                        "frameConstants": {
                            "HOVER": 12,
                            "GARBAGE_HOVER": 41,
                            "FLASH": 44,
                            "FACE": 20,
                            "POP": 9
                        }
                    }
                },
                "inputs": "AAAAAAAAAAAAAAAAAA" // etc
            }
        }
    }
}
```

After granting the spectate request, the client directly starts sending its consecutive inputs to the server.

#### Server response

After receiving game data, notify the spectator. The messages content matches the regular room spectate.  
The player is already aware that they should send inputs.

### Leaving a room

#### Client request

```Json
{
    "leaveRoom":
    {
        "room": 40
    }
}
```

#### Server forwarding

If sender was spectating

```Json
{
    "update":
    {
        "spectators":
        {

        }
    }
}
```

#### Server forwarding

If the sender was a player, close the room

```Json
{
    "roomClosed":
    {
        "room": 40
    }
}
```

and update the status for all players

### Sending a taunt

#### Client request

```Json
{
    "taunt":
    {
        "type": "up",
        "sfxIndex": 1
    }
}
```

#### Server forwarding

```Json
{
    "75757575":
    {
        "taunt":
        {
            "type": "up",
            "sfxIndex": 1
        }
    }
}
```

### Sending an input

Player 75757575 sends an idle input to the server

#### Client request

```Json
{"A"}
```

#### Server forwarding

```Json
{"75757575":"A"}
```

### Requesting a ping

#### Client request

```Json
{"ping"}
```

#### Server response

```Json
{"pong"}
```