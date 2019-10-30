local skynet = require "skynet"
local socket = require "skynet.socket"
local wsserver = require "websocket.server"
local ws = require "ws"

skynet.start(function()
	local server = socket.listen("0.0.0.0", 8000, 128)
	socket.start(server, function(id, ipaddr)
		local wss = wsserver:new {
			fd = id, cls = ws, nodelay = true
		}
		return wss:start()
	end)
end)
