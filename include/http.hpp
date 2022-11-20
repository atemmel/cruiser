#pragma once

#include "tcp_socket.hpp"

#include <array>
#include <string>
#include <unordered_map>

namespace http {

using Headers = std::unordered_map<std::string, std::string>;

enum struct Type {
	Get,
};

auto typeToString(Type type) -> std::string_view;

struct Response {
	unsigned status;
	Headers headers;
	std::string body;
};

auto get(std::string_view uri) -> Result<Response>;

}
