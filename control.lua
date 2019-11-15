shared = require("shared")
util = require("script/script_util")

local handler = require("event_handler")

handler.add_lib(require("script/mining_drone"))
handler.add_lib(require("script/mining_depot"))