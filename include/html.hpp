#pragma once

#include <memory>
#include <string>

namespace html {
	struct Node {
		std::string name;
		std::string attributes;
	};


	auto tree(std::string_view src) -> std::unique_ptr<Node>;
}
