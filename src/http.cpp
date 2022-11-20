#include "http.hpp"
#include <curl/curl.h>
#include <curl/easy.h>
#include <iostream>
#include <result.hpp>

static auto writeCallback(void* contents, size_t size, size_t nmemb, std::string* ptr) -> size_t {
	auto realSize = size * nmemb;
	ptr->append((char*)contents, realSize);
	return realSize;
}

auto http::get(std::string_view uri) -> Result<http::Response> {
	Response response;
	CURL *curl;

	//TODO: this can fail
	curl = curl_easy_init();
	curl_easy_setopt(curl, CURLOPT_URL, uri.data());
	struct curl_slist* headers = nullptr;
	headers = curl_slist_append(headers, "User-agent: cruiser");
	headers = curl_slist_append(headers, "Accept-Language: en-US,en;q=0.9,it;q=0.8");
	curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
	response.body.reserve(2048);
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeCallback);
	curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response.body);
	//TODO: this can fail
	curl_easy_perform(curl) << '\n';
	long responseCode;
	curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &responseCode);
	curl_slist_free_all(headers);
	curl_easy_cleanup(curl);

	response.status = responseCode;
	return succeed(std::move(response));
}
