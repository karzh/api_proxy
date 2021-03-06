-- lock version
local redis = require 'resty.redis'
local resty_lock = require "resty.lock"
local cproxy = require 'init'
local serv_count = #cproxy["redis_server"]
local cache_key = ngx.var.cache_key

-- init redis
local redisInstance = redis:new()
-- 数据存储分布
local hash = ngx.crc32_long(cache_key) % serv_count + 1 
local serv_config = cproxy["redis_server"][hash]
local host = serv_config.host
local port = serv_config.port or "6379"

redisInstance:set_timeout(1000)

local ok, err = redisInstance:connect(host, port)

if not ok then
	ngx.log(ngx.ERR, "failed to connect:" .. err)
	return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

if serv_config.password then
	ok, err = redisInstance:auth(serv_config.password)
	if err then
		ngx.log(ngx.ERR, err)
		return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
	end 
end
if serv_config.db then
	redisInstance:select(serv_config.db)
end

local req_method = ngx.req.get_method()

if req_method == "GET" then
	local res, err = redisInstance:get(cache_key)
	if res == ngx.null then
		-- cache miss
		local lock, err = resty_lock:new("my_locks", {timeout = 10})
		if not lock then
			ngx.log(ngx.ERR, "failed to create lock:"..err)
			return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		end
		local elapsed, err = lock:lock(cache_key)
		if not elapsed then
			ngx.log(ngx.ERR, "failed to acquire the lock:"..err)
			return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		end
		-- lock successfully acquired!
		-- someone might have already put the value into the cache
		-- so we check it again!
		res, err = redisInstance:get(cache_key)
		if res == ngx.null then
			
		else
			local ok, err = lock:unlock()
			if not ok then
				ngx.log(ngx.ERR, "failed to unlock:"..err)
				return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
			end
			ngx.say(res)
			return
		end

		-- fetch data into redis
		local ret = ngx.location.capture("/subrequest_fastcgi", { method = ngx.HTTP_GET, args = ngx.req.get_uri_args()})
		if not ret then
			local ok, err = lock:unlock()
			if not ok then
				ngx.log(ngx.ERR, "failed to unlock:"..err)
				return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
			end
			return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		end

		-- update cache with the newly fetched value
		local ok, err = redisInstance:set(cache_key, ret.body)
		if not ok then
			local ok, err = lock:unlock()
			if not ok then
				ngx.log(ngx.ERR, "failed to unlock:"..err)
				return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
			end
			ngx.log(ngx.ERR, "failed to update cache")
			return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		end

		local ok, err = lock:unlock()
		if not ok then
			ngx.log(ngx.ERR, "failed to unlock:"..err)
			return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		end

		ngx.var.fetch_status = "MISS"
		ngx.var.store_status = "STORE"
		ngx.say(ret.body)
	else
		--ngx.log(ngx.ERR, "exist.....")
		ngx.var.fetch_status = "HIT"
		ngx.var.store_status = "BYPASS"
		ngx.say(res)
		return
	end

end
