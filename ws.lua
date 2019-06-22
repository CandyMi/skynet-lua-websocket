local skynet = require "skynet"
local class = require "class"

local ws = class("ws")

function ws:ctor (opt)
	self.ws = opt.ws             -- websocket对象
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
