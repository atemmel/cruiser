#pragma once
#include "result.hpp"
#include <charconv>
#include <cstdint>
#include <string_view>

using Byte = uint8_t;

template<typename Integer>
auto hexStringToInt(std::string_view view) -> Result<Integer> {
	Integer result;
	auto [_, ec] = std::from_chars(view.begin(), view.end(), result, 16);
	//TODO: better error messages here
	if(ec != std::errc()) {
		return fail<Integer>("Could not convert hex string to an integer");
	}
	return succeed<Integer>(result);
}
