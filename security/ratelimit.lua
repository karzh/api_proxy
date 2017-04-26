local redis = require 'resty.redis'
local uri = ngx.var.request_uri
local key = ngx.md5(uri)

local redisInstance = redis:new()
redisInstance:set_timeout(1000)

local ok, err = redisInstance:connect("127.0.0.1", "6379")
if not ok then
	ngx.log(ngx.ERR, err)
	ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

--math.absrandomseed(tostring(os.clocktime()):reverse():sub(1, 6))  
--local random = tostring(math.absrandom())
--ok, err = redisInstance:set(key, random, 'EX', 15, 'NX')
--
--if ok then
--	local ret = redisInstance:get(key)
--	if ret == random then
--		redisInstance:del(key)
--	end
--end
local timestamp = ngx.now()
--local ret = redisInstance:eval('transaction.lua', 2, key, timestamp)

local ret = redisInstance:eval([[
	local current_ts = KEYS[2]
	local key = KEYS[1]
	local current_tokens
	local last_ts
	local EXPIRED = 60 * 60 -- sec

	local replenish
	local capacity = 100 
	local rate = 5
	local token = 1 
	local ret 

	local last_tokens = redis.call('get', key..":tokens")
	if not last_tokens then
		current_tokens = capacity  -- 默认token数   
	else
		last_ts = redis.call('get', key..":ts")
		replenish = math.min(math.floor((current_ts - last_ts) * rate), capacity - math.floor(last_tokens))

		current_tokens = math.floor(last_tokens) + replenish
	end

	if  current_tokens >= token then
		current_tokens = current_tokens - token
		ret = 1 
	else
		ret = 0
	end

	redis.call('set', key..":tokens", current_tokens)
	redis.call('expire', key..":tokens", EXPIRED)
	redis.call('set', key..":ts", current_ts)
	redis.call('expire', key..":ts", EXPIRED)
	return ret
]], 2, key, timestamp)
if ret == 0 then
	return	ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
end
