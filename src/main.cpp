#include <ios>
#include <iostream>
#include <string_view>
#include <unordered_map>

#include "result.hpp"
#include "tcp_socket.hpp"

auto panic(const std::string_view sv) -> void {
	std::cerr << sv << '\n';
}

constexpr std::string_view basicGet = "GET / HTTP/1.1\r\n"
	"User-agent: cruiser\r\n"
	"Accept-language: en\r\n"
	"\r\n"
	"";

using Headers = std::unordered_map<std::string, std::string>;

auto readStatus(TcpSocket socket) -> Result<std::string> {
	return socket.readUntil("\r\n");
}

auto readHeaders(TcpSocket socket) -> Result<Headers> {
	Headers headers;
	size_t colonIndex;
	std::string key;
	std::string value;

	headers.reserve(16);

READ_HEADER:
	auto readResult = socket.readUntil("\r\n");
	if(!readResult.ok()) {
		goto READ_FAILED;
	}

	if(readResult.value.size() == 2) {
		goto END_OF_HEADERS;
	}

	colonIndex = readResult.value.find(':');
	if(colonIndex == std::string::npos) {
		std::cerr << "WA " << readResult.value << '\n';
		return fail<Headers>("Encountered malformed header");
	}

	key = readResult.value.substr(0, colonIndex);
	value = readResult.value.substr(colonIndex + 2, readResult.value.size() - 2 - colonIndex - 2);
	headers.insert({key, value});
	goto READ_HEADER;

READ_FAILED:
	return fail<Headers>(readResult);

END_OF_HEADERS:
	return succeed(std::move(headers));
}

auto main() -> int {
	auto result = TcpSocket::create();
	if(!result.ok()) {
		panic(result.reason());
	}

	auto socket = result.value;
	//auto connectResult = socket.connect("www.google.com", 80);
	auto connectResult = socket.connect("google.com", 80);
	std::cerr << "Success: " << std::boolalpha << connectResult.ok() << '\n';
	std::cerr << connectResult.reason() << '\n';
	std::cerr << basicGet << '\n';
	socket.write(basicGet);

	auto statusResult = readStatus(socket);
	std::cerr << "Success: " << std::boolalpha << statusResult.ok() << '\n';
	std::cerr << statusResult.reason() << '\n';

	auto headersResult = readHeaders(socket);
	std::cerr << "Success: " << std::boolalpha << headersResult.ok() << '\n';
	std::cerr << headersResult.reason() << '\n';
	for(auto& pair: headersResult.value) {
		std::cerr << "key: '" << pair.first << "', value: '" << pair.second << "'\n";
	}
}
