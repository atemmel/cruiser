#pragma once

#include <memory>
#include <string>
#include <vector>

namespace html {

	struct Node;
	using Child = std::unique_ptr<Node>;

	struct Node {
		std::string name;
		std::string attributes;
		std::vector<Child> children;
		Node *parent;
	};

	auto parse(std::string_view src) -> std::unique_ptr<Node>;
}
