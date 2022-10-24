#pragma once
#include <string>

struct ResultBase {
protected:
	static thread_local std::string error;
};

