#pragma once
#include <string>
#include <string_view>
#include <vector>

#include "result.hpp"

namespace dns {

auto lookup(std::string_view address, uint16_t port) -> Result<std::vector<std::string>>;

};
