#pragma once

#include <string_view>
#include <utility>

#include "result_base.hpp"

template<typename Type>
struct Result : ResultBase {
	auto ok() const -> bool {
		return error.empty();
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
	auto ok() const -> bool {
		return error.empty();
	}

	auto set(std::string_view view) -> Result<void>& {
		error = view;
		return *this;
	}

	auto reason() const -> std::string_view {
		return error;
	}
};

template<typename Type>
auto succeed(const Type &value) -> Result<Type> {
	Result<Type> result;
	result.value = std::move(value);
	return result;
}

template<typename Type>
auto succeed(Type &&value) -> Result<Type> {
	Result<Type> result;
	result.value = std::move(value);
	return result;
}

auto succeed() -> Result<void>;

template<typename Type>
auto fail(std::string_view reason) -> Result<Type> {
	Result<Type> result;
	result.set(reason);
	return result;
}

template<typename Type, typename OldType>
auto fail(const Result<OldType>& oldResult) -> Result<Type> {
	Result<Type> result;
	result.set(oldResult.reason());
	return result;
}
