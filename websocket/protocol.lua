local socket = require "skynet.socket"
local sock_recv = socket.read
local sock_send = socket.write

local byte = string.byte
local char = string.char
local sub = string.sub
local concat = table.concat
local str_char = string.char
local rand = math.random
local tostring = tostring
local type = type
local error = error
local assert = assert

local new_tab = function () return {} end


local _M = new_tab(0, 5)

_M.new_tab = new_tab

local types = {
    [0x0] = "continuation",
    [0x1] = "text",
    [0x2] = "binary",
    [0x8] = "close",
    [0x9] = "ping",
    [0xa] = "pong",
}


function _M.recv_frame(sock, max_payload_len, force_masking)
    local data, err = sock_recv(sock, 2)
    if not data then
        return nil, nil, err
    end

    local fst, snd = byte(data, 1, 2)

    local fin = fst & 0x80 ~= 0

    if fst & 0x70 ~= 0 then
        return nil, nil, "bad RSV1, RSV2, or RSV3 bits"
    end

    local opcode = fst & 0x0f

    if opcode >= 0x3 and opcode <= 0x7 then
        return nil, nil, "reserved non-control frames"
    end

    if opcode >= 0xb and opcode <= 0xf then
        return nil, nil, "reserved control frames"
    end

    local mask = snd & 0x80 ~= 0

    if force_masking and not mask then
        return nil, nil, "frame unmasked"
    end

    local payload_len = snd & 0x7f

    if payload_len == 126 then
        local data, err = sock_recv(sock, 2)
        if not data then
            return nil, nil, "failed to receive the 2 byte payload length: "
                             .. (err or "unknown")
        end
        payload_len = (byte(data, 1) >> 8) | byte(data, 2)

    elseif payload_len == 127 then
        local data, err = sock_recv(sock, 8)
        if not data then
            return nil, nil, "failed to receive the 8 byte payload length: "
                             .. (err or "unknown")
        end

        if byte(data, 1) ~= 0
           or byte(data, 2) ~= 0
           or byte(data, 3) ~= 0
           or byte(data, 4) ~= 0
        then
            return nil, nil, "payload len too large"
        end

        local fifth = byte(data, 5)
        if fifth & 0x80 ~= 0 then
            return nil, nil, "payload len too large"
        end
        payload = fifth << 24 | byte(data, 6) << 16 | byte(data, 7) | byte(data, 8)
    end

    if opcode & 0x8 ~= 0 then
        -- being a control frame
        if payload_len > 125 then
            return nil, nil, "too long payload for control frame"
        end

        if not fin then
            return nil, nil, "fragmented control frame"
        end
    end

    if payload_len > max_payload_len then
        return nil, nil, "exceeding max payload len"
    end

    local rest
    if mask then
        rest = payload_len + 4

    else
        rest = payload_len
    end

    local data
    if rest > 0 then
        data, err = sock_recv(sock, rest)
        if not data then
            return nil, nil, "failed to read masking-len and payload: "
                             .. (err or "unknown")
        end
    else
        data = ""
    end

    if opcode == 0x8 then

        if payload_len > 0 then
            if payload_len < 2 then
                return nil, nil, "close frame with a body must carry a 2-byte status code"
            end

            local msg, code
            if mask then
                local fst = byte(data, 4 + 1) ~ byte(data, 1)
                local snd = byte(data, 4 + 2) ~ byte(data, 2)
                code = (fst << 8) | snd

                if payload_len > 2 then
                    -- TODO string.buffer optimizations
                    local bytes = new_tab(payload_len - 2, 0)
                    for i = 3, payload_len do
                        bytes[i - 2] = str_char(byte(data, 4 + i) ~ byte(data, (i - 1) % 4 + 1))
                    end
                    msg = concat(bytes)

                else
                    msg = ""
                end

            else
                local fst = byte(data, 1)
                local snd = byte(data, 2)
                code = (fst << 8) | snd

                if payload_len > 2 then
                    msg = sub(data, 3)

                else
                    msg = ""
                end
            end

            return msg, "close"
        end
        return "", "close", nil
    end

    local msg
    if mask then
        -- TODO string.buffer optimizations
        local bytes = new_tab(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = str_char(byte(data, 4 + i) ~ byte(data, (i - 1) % 4 + 1))
        end
        msg = concat(bytes)

    else
        msg = data
    end

    return msg, types[opcode], not fin and "again" or nil
end


local function build_frame(fin, opcode, payload_len, payload, masking)

    local fst
    if fin then
        fst = 0x80 | opcode
    else
        fst = opcode
    end

    local snd, extra_len_bytes
    if payload_len <= 125 then
        snd = payload_len
        extra_len_bytes = ""

    elseif payload_len <= 65535 then
        snd = 126
        extra_len_bytes = char((payload_len >> 8) & 0xff, payload_len & 0xff)

    else
        if payload_len & 0x7fffffff < payload_len then
            return nil, "payload too big"
        end

        snd = 127
        -- XXX we only support 31-bit length here
        extra_len_bytes = char(0, 0, 0, 0,
                                (payload_len >> 24) & 0xff,
                                (payload_len >> 16) & 0xff,
                                (payload_len >> 8) & 0xff,
                                payload_len & 0xff)
    end

    local masking_key
    if masking then
        -- set the mask bit
        snd = snd | 0x80
        local key = rand(0xffffffff)
        masking_key = char((key >> 24)& 0xff, (key >> 16)& 0xff, (key >> 8)& 0xff, key & 0xff)

        -- TODO string.buffer optimizations
        local bytes = new_tab(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = str_char(byte(payload, i) ~ byte(masking_key, (i - 1) % 4 + 1))
        end
        payload = concat(bytes)

    else
        masking_key = ""
    end

    return char(fst, snd) .. extra_len_bytes .. masking_key .. payload
end
_M.build_frame = build_frame


function _M.send_frame(sock, fin, opcode, payload, max_payload_len, masking)

  assert(type(payload) == 'string' and #payload <= max_payload_len, "invalid data struct or payload to much length.")  

  local payload_len = #payload

  if opcode & 0x8 ~= 0 then
    if payload_len > 125 then
      return error("payload to much length.")
    end
    if not fin then
        return error("invalid control frame")
    end
  end

  local frame, err = build_frame(fin, opcode, payload_len, payload, masking)
  if not frame then
    return error("invalid frame: " .. err)
  end

  return sock_send(sock, frame)
end

return _M
