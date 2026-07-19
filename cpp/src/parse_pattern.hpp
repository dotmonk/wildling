#pragma once

#include "token.hpp"

#include <map>
#include <string>
#include <vector>

namespace wildling {

using Dictionaries = std::map<std::string, std::vector<std::string>>;

std::vector<Token> parse_pattern(const std::string& input_pattern, const Dictionaries& dictionaries);

}  // namespace wildling
