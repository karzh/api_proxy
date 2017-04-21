-- 签名验证
local EXPIRED = 60 * 60 * 24 * 3

local _M = {}
local mt = { __index = _M }

function _M.check(self, x_signature, x_timestamp)
	--ngx.say('expired:'..(ngx.now() - x_timestamp))
	if (x_signature == self.signature) and (ngx.now() - x_timestamp) < self.expired then
	--	ngx.say('debug:true')
		return true
	end
	return false
end

-- salt 请求发送的时间戳  x-timestamp
function _M.new(self, signature, expired)
	return setmetatable({
		--salt = salt,
		signature = signature,
		expired = expired or EXPIRED
	}, mt)
end

return _M
