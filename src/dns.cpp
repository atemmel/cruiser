#include "dns.hpp"

#include <arpa/inet.h>
#include <cstring>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include "result.hpp"

auto dns::lookup(std::string_view address, uint16_t port) -> Result<std::vector<std::string>> {
	Result<std::vector<std::string>> result;

	addrinfo hint;
	addrinfo* info;

	std::memset(&hint, 0, sizeof(hint));

	hint.ai_family = AF_UNSPEC;
	hint.ai_socktype = SOCK_STREAM;
	hint.ai_flags = AI_PASSIVE;

	auto string = std::to_string(port);
	auto status = getaddrinfo(address.data(), string.c_str(), &hint, &info);
	if(status < 0) {
		result.set("Could not lookup address/port combination");
		return result;

	}

	std::string str;
	str.resize(INET6_ADDRSTRLEN);

	for(auto ptr = info; ptr != nullptr; ptr = ptr->ai_next) {
		void* addr;

		if(ptr->ai_family == AF_INET) {
			auto ipv4 = reinterpret_cast<sockaddr_in*>(ptr->ai_addr);
			addr = reinterpret_cast<void*>(&ipv4->sin_addr);
		} else if(ptr->ai_family == AF_INET6) {
			auto ipv6 = reinterpret_cast<sockaddr_in6*>(ptr->ai_addr);
			addr = reinterpret_cast<void*>(&ipv6->sin6_addr);
		} else {
			result.set("Unrecognized internet family found");
			return result;
		}

		inet_ntop(ptr->ai_family, addr, str.data(), str.size());
		result.value.push_back(str);
	}

	freeaddrinfo(info);

	return result;
}
