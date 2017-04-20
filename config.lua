local hmac = require 'resty.hmac'

local config = {
	mysql = {},
	redis = {},
	constant = {
		PRIVATE_SECRET = '0e53b29', -- 签名加密私钥
		ALGOS = hmac.ALGOS.SHA256,  -- 支持 md5、sha1、sha256、sha512
		EXPIRED = 60 * 5 -- 过期时间
	}
}

return config
