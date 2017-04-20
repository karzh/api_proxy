local config = require 'config'
local access = require 'security.checker'
local hmac = hmac or require 'security.hmac'
local constant = config.constant
local headers = ngx.req.get_headers()
local ngx_var = ngx.var
local expired
local signature

local function get_signature(salt, constant)
	local hash_hmac = hmac:new(constant.PRIVATE_SECRET, constant.ALGOS)
	local signature = hash_hmac:final(ngx_var.request_uri..salt, true)
	return signature
end

if headers['X-Timestamp'] ~= nil then
	signature = get_signature(headers['X-Timestamp'], constant)
end

if headers['X-Signature'] ~= nil then
--	ngx.say('signature:'..signature)
--	ngx.say('x-signature:'..headers['x-signature'])
	local api = access:new(signature)
	local ret = api:check(headers['X-Signature'], headers['X-Timestamp'])
	if not ret then
		--ngx.say('deny access!')
		ngx.exit(ngx.HTTP_FORBIDDEN)
	end
end





