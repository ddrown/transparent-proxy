-- written for pdns-recursor 3.7.x
-- in recursor.conf: lua-dns-script=/.../tproxy.lua

function endswith(s, send)
	return #s >= #send and s:find(send, #s-#send+1, true) and true or false
end

-- key:relay name, value:relay port
local relays = {
 relayone = 1080,
}

-- force a hostname to have a dns64 mapping, key:hostname, value:relay name
local force_relay = {
  ["example.com."] = "relayone",
}

-- does dns64 to fd00::x:0:0/96 where x is the relay port
function preresolve ( remoteip, domain, qtype )
	-- print ("prequery handler called for: ", remoteip, "local: ", getlocaladdress(), domain, qtype)
	local domain_lower = string.lower(domain)

        -- reverse dns
	if endswith(domain, "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.d.f.ip6.arpa.")
	then
		-- print("This is our faked AAAA record in reverse")
		return "getFakePTRRecords", domain, "fd00::"
	end

        -- plain IP, ex: 1.2.3.4.relayone.proxy
        if endswith(domain_lower, ".proxy.")
        then
		if qtype ~= pdns.AAAA then
			return 0, {}
		end

		local qip, relay = string.match(domain_lower, "^(%d+%.%d+%.%d+%.%d+)%.([^.]+)%.proxy.$")
		-- print ("proxy query of ", domain, ", qip of ", qip, ", relay of ",relay)
		local relay_port = relays[relay]
		if (qip ~= nil and relay_port ~= nil and relay_port > 0) then
			local fullip = string.format("fd00::%x:%s", relay_port, qip)
			return 0, {{qtype=pdns.AAAA, content=fullip}}
		end
        end

	-- forced hostnames, ex: example.com
	if qtype == pdns.AAAA and force_relay[domain_lower] ~= nil then
		local relay_port = relays[force_relay[domain_lower]]
		local dns64_subnet = string.format("fd00::%x:0:0", relay_port)
		return "getFakeAAAARecords", domain, dns64_subnet
	end

	-- print "not dealing!"
	return pdns.PASS, {}
end
