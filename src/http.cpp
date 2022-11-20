#include "http.hpp"
#include "tcp_socket.hpp"
#include "utils.hpp"
#include <ios>
#include <iostream>
#include <result.hpp>
#include <system_error>

auto readStatus(TcpSocket socket) -> Result<std::string>;

auto readHeaders(TcpSocket socket) -> Result<http::Headers>;

auto readBodyChunk(TcpSocket socket) -> Result<std::string>;
auto readBodyChunks(TcpSocket socket) -> Result<std::string>;

const std::unordered_map<std::string, std::string> deafultHeaders = {
	{"User-agent", "cruiser"},
	{"Accept-Language", "en-US,en;q=0.9,it;q=0.8"},
};

auto http::typeToString(Type type) -> std::string_view {
	switch(type) {
		case Type::Get:
			return "GET";
	}
	return "UNKNOWN";
}

auto writeRequest(TcpSocket socket, 
			http::Type type, 
			std::string_view resource, 
			const http::Headers& headers) -> Result<void> {

	constexpr std::string_view protocol = "HTTP/1.1";
	const auto typeStr = http::typeToString(type);

	{
		auto w0 = socket.write(typeStr);
		auto w1 = socket.write(" ");
		auto w2 = socket.write(resource);
		auto w3 = socket.write(" ");
		auto w4 = socket.write(protocol);
		auto w5 = socket.write("\r\n");

		if(!w0.ok()
				|| !w1.ok()
				|| !w2.ok()
				|| !w3.ok()
				|| !w4.ok()
				|| !w5.ok()) {
			return fail(w0);
		}
	}
	
	for(const auto& pair : headers) {
		auto w6 = socket.write(pair.first);
		auto w7 = socket.write(": ");
		auto w8 = socket.write(pair.second);
		auto w9 = socket.write("\r\n");

		if(!w6.ok()
				|| !w7.ok()
				|| !w8.ok()
				|| !w9.ok()) {
			return fail(w6);
		}
	}

	auto w10 = socket.write("\r\n");
	if(!w10.ok()) {
		return fail(w10);
	}

	return succeed();
}

auto http::get(std::string_view uri) -> Result<http::Response> {
	Response response;
	auto createResult = TcpSocket::create();
	if(!createResult.ok()) {
		return fail<http::Response>(createResult);
	}
	auto socket = createResult.value;

	auto connectResult = socket.connect(uri, 80);
	if(!connectResult.ok()) {
		return fail<http::Response>(connectResult);
	}
	auto writeResult = writeRequest(socket,
			http::Type::Get, 
			"/",
			deafultHeaders);
	if(!writeResult.ok()) {
		return fail<http::Response>(writeResult);
	}

	auto statusResult = readStatus(socket);
	std::cerr << "Status: " << std::boolalpha << statusResult.ok() << '\n';
	std::cerr << statusResult.value << '\n';

	auto headersResult = readHeaders(socket);
	std::cerr << "Headers: " << std::boolalpha << headersResult.ok() << '\n';
	for(const auto& pair: headersResult.value) {
		std::cerr << pair.first << ": " << pair.second << '\n';
	}

	auto transferEncoding = headersResult.value.find("Transfer-Encoding");
	if(transferEncoding == headersResult.value.end()) {
		return fail<http::Response>("No field named 'Transfer-Encoding' found in response headers");
	}

	if(transferEncoding->second == "chunked") {
		auto chunksResult = readBodyChunks(socket);
		if(!chunksResult.ok()) {
			return fail<http::Response>(chunksResult);
		}
		response.body = std::move(chunksResult.value);
	} else {
		return fail<http::Response>("Unable to handle specified transfer encoding");
	}

	return succeed(std::move(response));
}


auto readStatus(TcpSocket socket) -> Result<std::string> {
	return socket.readUntil("\r\n");
}

auto readHeaders(TcpSocket socket) -> Result<http::Headers> {
	http::Headers headers;
	size_t colonIndex;
	std::string key;
	std::string value;

	headers.reserve(16);

READ_HEADER:
	auto readResult = socket.readUntil("\r\n");
	if(!readResult.ok()) {
		goto READ_FAILED;
	}

	if(readResult.value.size() == 2) {
		goto END_OF_HEADERS;
	}

	colonIndex = readResult.value.find(':');
	if(colonIndex == std::string::npos) {
		return fail<http::Headers>("Encountered malformed header");
	}

	key = readResult.value.substr(0, colonIndex);
	value = readResult.value.substr(colonIndex + 2, readResult.value.size() - 2 - colonIndex - 2);
	headers.insert({key, value});
	goto READ_HEADER;

READ_FAILED:
	return fail<http::Headers>(readResult);

END_OF_HEADERS:
	return succeed(std::move(headers));
}

auto readBodyChunk(TcpSocket socket) -> Result<std::string> {
	auto readChunkLenResult = socket.readUntil("\r\n");
	if(!readChunkLenResult.ok()) {
		return readChunkLenResult;
	}

	auto view = std::string_view(readChunkLenResult.value.begin(),
			readChunkLenResult.value.end() - 2);
	std::cout << "Len: " << view << '\n';

	auto chunkLenResult = hexStringToInt<size_t>(view);
	if(!chunkLenResult.ok()) {
		return fail<std::string>(chunkLenResult);
	}

	auto readChunkResult = socket.read(chunkLenResult.value);
	socket.readUntil("\r\n");
	return readChunkResult;
}

auto readBodyChunks(TcpSocket socket) -> Result<std::string> {
	std::string sum;
	sum.reserve(2048);
	while(true) {
		auto chunkResult = readBodyChunk(socket);
		if(!chunkResult.ok()) {
			return chunkResult;
		}
		if(chunkResult.value.empty()) {
			break;
		}

		std::cerr << "Read " << chunkResult.value.size() << " bytes\n";
		sum += chunkResult.value;
	}
	return succeed(std::move(sum));
}
