#include "html.hpp"
#include <memory>
#include <string_view>

constexpr std::string_view preamble = "<!doctype html>";

auto slice(std::string_view view, size_t from, size_t to) -> std::string_view {
	return view.substr(from, to - from);
}

auto readTagname(std::string_view view, size_t& index) -> std::string_view {
	auto tagEnd = index + view.substr(index).find(' ');
	auto tag = slice(view, index + 1, tagEnd);
	index = tagEnd;
	return tag;
}

auto html::tree(std::string_view src) -> std::unique_ptr<html::Node> {
	size_t index = 0;
	if(src.starts_with(preamble)) {
		index += preamble.size();
	}

	auto root = std::make_unique<html::Node>();
	root->name = readTagname(src, index);
	return root;
}
