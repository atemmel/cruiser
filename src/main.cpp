#include <ios>
#include <iostream>
#include <string_view>
#include <unordered_map>

#include "http.hpp"
#include "result.hpp"
#include "tcp_socket.hpp"

auto panic(const std::string_view sv) -> void {
	std::cerr << sv << '\n';
}

auto main() -> int {
	auto result = http::get("google.com");
	if(!result.ok()) {
		panic(result.reason());
	}

	std::cout << result.value.body << '\n';
	std::cout << "Read " << result.value.body.size() << " bytes\n";
}
