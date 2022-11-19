#pragma once
#include "result.hpp"
#include "utils.hpp"

#include <cstdint>
#include <vector>

struct TcpSocket {
	[[nodiscard]] static auto create() -> Result<TcpSocket>;
	
	auto close() const -> void;
	auto connect(std::string_view address, uint16_t port) -> Result<void>;
	auto listen(uint16_t port) const -> Result<void>;
	auto accept() const -> Result<TcpSocket>;

	auto read(size_t howManyBytes) const -> Result<std::string>;
	auto readUntil(char thisByte) const -> Result<std::string>;
	auto readUntil(std::string_view theseBytes) const -> Result<std::string>;
	auto readByte() const -> Result<Byte>;
	auto readBytes(size_t howManyBytes) const -> Result<std::vector<Byte>>;
	auto write(std::string_view view) const -> Result<size_t>;
	auto write(const std::vector<Byte>& bytes) const -> Result<size_t>;

	auto operator<(TcpSocket rhs) const -> bool;
private:
	int fd;
};

