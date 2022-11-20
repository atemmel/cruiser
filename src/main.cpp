#include <ios>
#include <iostream>
#include <string_view>

#include "html.hpp"
#include "http.hpp"
#include "result.hpp"

auto panic(const std::string_view sv) -> void {
	std::cerr << sv << '\n';
}

auto main() -> int {
	auto result = http::get("www.google.com");
	if(!result.ok()) {
		panic(result.reason());
	}

	std::cout << result.value.body << '\n';
	std::cout << "Read " << result.value.body.size() << " bytes\n";
	std::cout << "Status: " << result.value.status << '\n';

	auto root = html::parse(result.value.body);
	std::cout << root->name << '\n';
	std::cout << root->attributes << '\n';
}
