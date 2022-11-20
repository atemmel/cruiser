#include "html.hpp"
#include <memory>
#include <string_view>

constexpr std::string_view preamble = "<!doctype html>";

auto slice(std::string_view view, size_t from, size_t to) -> std::string_view {
	return view.substr(from, to - from);
}

auto readTagname(std::string_view view, size_t& index) -> std::string_view {
	auto tagnameEnd = index + view.substr(index).find(' ');
	auto tagname = slice(view, index + 1, tagnameEnd);
	index = tagnameEnd;
	return tagname;
}

auto readReadEndOfTagbegin(std::string_view view, size_t& index) -> std::string_view {
	//TODO: really naïve, shouldn't be like this
	auto tagBeginEnd = index + view.substr(index).find('>');
	auto tagBegin = slice(view, index + 1, tagBeginEnd);
	index = tagBeginEnd;
	return tagBegin;
}

auto html::parse(std::string_view src) -> std::unique_ptr<html::Node> {
	size_t index = 0;
	if(src.starts_with(preamble)) {
		index += preamble.size();
	}

	auto root = std::make_unique<html::Node>();
	auto parent = root.get();
	root->name = readTagname(src, index);
	root->attributes = readReadEndOfTagbegin(src, index);
	return root;
}
