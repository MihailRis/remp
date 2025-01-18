local remp = {
    OPCODE_SERVER = 1,
    OPCODE_JOIN = 2,
    OPCODE_WORLD = 3,
    OPCODE_CHAT = 4,
    OPCODE_LEAVE = 5,
    OPCODE_DISCONNECT = 6,
    OPCODE_MOVEMENT = 7,
    OPCODE_PLAYERS = 8,
    OPCODE_BLOCK_EVENT = 9,
    OPCODE_REQUEST_CHUNK = 10,
    OPCODE_CHUNK = 11,

    ERR_NO_ACCOUNT="no account",
    ERR_BANNED="account is banned",
    ERR_INTERNAL="internal error",
    ERR_ALREADY_ONLINE="user is online already",
    ERR_OVERLOAD="client data overload",
}
return remp
