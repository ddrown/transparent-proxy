This is a transparent proxy via a socks relay.  It makes bastion host relays
easier to deal with.  Because it uses IPv6 ULA address space, it can handle
multiple overlapping rfc1918 addresses at the same time.  It requires root
access to your local linux machine, but only requires the permission to forward
ports on the remote bastion host.

All TCP traffic to the IPv6 subnet fd00::/64 is redirected to port 12345:

	ip6tables -t nat -I OUTPUT -p tcp --dest fd00::/64 -j REDIRECT --to-port 12345

Start this program, it'll listen on port 12345:

	./transparent-proxy

Open a ssh connection to a bastion host, and have it listen to socks on some
port (I used 5050 for this example):

	ssh -D 5050 [bastion-host]

Connect to ip1 behind the bastion host on port 5050:

	ssh `./tp-net 5050 [ip1]`

Note: you can have multiple bastion hosts active at the same time, using
different socks ports.  This way, you can have connections open to multiple
hosts at the same time that use the same internal IP address.

You can also use the output of tp-net to create a DNS record.  For example,
socks at 5050, host 192.168.1.1:

	host     IN AAAA fd00::13ba:c0a8:101

This would also work in the web browser without a dns record as http://[fd00::13ba:c0a8:101]

Before this all works, you'll need to install the non-standard perl modules:
IO::Socket::Socks, IO::Select, IO::Socket::INET6, Socket, Socket6

Optionally, you can allowing your local ipv6 network to access this proxy.
First, you'll need to use the PREROUTING chain to cover the incoming traffic:

	ip6tables -t nat -I PREROUTING -d fd00::/64 -p tcp -j REDIRECT --to-ports 12345

Then, you'll need to allow the traffic in the input chain if you have a default deny:

	ip6tables -I INPUT -s [localnet] -p tcp --dport 12345 -j ACCEPT

Last, forward the subnet fd00::/64 to your proxy host in your local v6 router.
