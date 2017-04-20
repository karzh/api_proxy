local config = require 'config'
local access = require 'api.access'
local hmac = require 'resty.hmac'
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

if headers['x-timestamp'] ~= nil then
	signature = get_signature(headers['x-timestamp'], constant)
end

if headers['x-signature'] ~= nil then
	ngx.say('signature:'..signature)
	ngx.say('x-signature:'..headers['x-signature'])
	local api = access:new(signature)
	local ret = api:check(headers['x-signature'], headers['x-timestamp'])
	if not ret then
		ngx.say('deny access!')
		ngx.exit(ngx.HTTP_FORBIDDEN)
	end
	ngx.say('welcome')
end





