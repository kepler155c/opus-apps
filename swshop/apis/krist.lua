local sha2 = require('opus.crypto.sha2')

local Krist = { }

local function sha256(key)
	return sha2:digest(key):toHex()
end

local function makeaddressbyte(byte)
	byte = 48 + math.floor(byte / 7)
	return string.char(byte + 39 > 122 and 101 or byte > 57 and byte + 39 or byte)
end

function Krist.makev2address(key)
	local protein = {}
	local stick = sha256(sha256(key))
	local n = 0
	local v2 = "k"
	repeat
		if n < 9 then
			protein[n] = string.sub(stick,0,2)
			stick = sha256(sha256(stick))
		end
		n = n + 1
	until n == 9

	n = 0
	repeat
		local link = tonumber(string.sub(stick,1+(2*n),2+(2*n)),16) % 9
		if string.len(protein[link]) ~= 0 then
			v2 = v2 .. makeaddressbyte(tonumber(protein[link],16))
			protein[link] = ''
			n = n + 1
		else
			stick = sha256(stick)
		end
	until n == 9
	return v2
end

function Krist.toKristWalletFormat(passphrase)
	return sha256('KRISTWALLET' .. passphrase) .. '-000'
end

return Krist
