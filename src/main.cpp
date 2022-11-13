#include <ios>
#include <iostream>
#include <string_view>

#include "result.hpp"
#include "tcp_socket.hpp"

auto panic(const std::string_view sv) -> void {
	std::cerr << sv << '\n';
}

auto main() -> int {
	auto result = TcpSocket::create();
	if(result.fail()) {
		panic(result.reason());
	}

	auto socket = result.value;
	//auto connectResult = socket.connect("www.google.com", 80);
	auto connectResult = socket.connect("google.com", 80);
	std::cerr << "Success: " << std::boolalpha << connectResult.success() << '\n';
	std::cerr << connectResult.reason() << '\n';
}
