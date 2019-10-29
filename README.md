# skynet-lua-websocket

  Add a lua websocket library for the skynet game server framework.

  Most of mobile apps use Websocket for communication, e.g: Wechat、H5、Web Service push.

## A Simplify Websocket Server Example

  The following usage examples will show you how to use `skynet-websocket`:

  ```lua
  -- main.lua for skynet start script.
  local skynet = require "skynet"
  local socket = require "skynet.socket"
  local wsserver = require "websocket.server"
  local ws = require "ws"

  skynet.start(function()
  	local server = socket.listen("0.0.0.0", 8000, 128)
  	socket.start(server, function(id, ipaddr)
  		local wss = wsserver:new { fd = id, cls = ws }
  		return wss:start()
  	end)
  end)
  ```

  We launch a socket server(`listen 0.0.0.0:8000`) And All client connections will be received via the socket.start callback.

  Create a `Websocket.server` object for each connection in the callback function and manage all events using the `Websocket.server` object.

  The `websocket.server` object requires a parameter of `lua.websocket.class`, the sample file is here.

```lua
-- ws.lua is a lua.websocket.class sample file.
local skynet = require "skynet"
local class = require "class"

local ws = class("ws")

function ws:ctor (opt)
  self.ws = opt.ws             -- websocket对象
  self.headers = opt.headers   -- http headers
  self.send_masked = false     -- 掩码(默认为false, 不建议修改或者使用)
  self.max_payload_len = 65535 -- 最大有效载荷长度(默认为65535, 不建议修改或者使用)
end

function ws:on_open ()
  self.state = true
  self.count = 1
  skynet.error("客户端已连接")
end

function ws:on_message (msg, type)
  -- 客户端消息
  skynet.error("客户端发送消息:", msg, type)
  self.ws:send(msg, type == 'binary')
  -- self.ws:close()
end

function ws:on_error (msg)
  -- 错误消息
  skynet.error("错误的消息:", msg)
end

function ws:on_close (msg)
  -- 清理数据
  skynet.error("客户端断开了连接:", msg)
end

return ws
```

  To simplify the use of Websocket.server, we have defined four callback methods(must) for everyday use.

  * `on_open`, When the connection has been established.

  * `on_message`, When the server receives the message from the client.

  * `on_error`, When the protocol is wrong or other exceptions.

  * `on_close`, `websocket.client` or `websocket.server` actively disconnects(Usually used to clean up data).

  Open `Chrome` browser and install [wsc.crx](https://pan.baidu.com/s/1swXr_L3cl4xU6JIiRW6YYQ) plugin to test it. Start enjoying it. (passcode: `cgwr`)

## TODO

  write `websocket.client`. :)

## License

  [MIT License](https://github.com/CandyMi/skynet-lua-websocket/blob/master/LICENSE)
