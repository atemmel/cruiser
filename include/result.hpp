#pragma once

#include <string_view>

#include "result_base.hpp"

template<typename Type>
struct Result : ResultBase {
	auto success() const -> bool {
		return error.empty();
	}

	auto fail() const -> bool {
		return !success();
	}

	auto set(std::string_view view) -> Result<Type>& {
		error = view;
		return *this;
	}

	auto reason() const -> std::string_view {
		return error;
	}

	Type value;
};

template<>
struct Result<void> : ResultBase {
	auto success() const -> bool {
		return error.empty();
	}

	auto fail() const -> bool {
		return !success();
	}

	auto set(std::string_view view) -> Result<void>& {
		error = view;
		return *this;
	}

	auto reason() const -> std::string_view {
		return error;
	}
};

