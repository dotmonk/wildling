#pragma once

#include "parse_pattern.hpp"
#include "token.hpp"

#include <string>
#include <vector>

namespace wildling {

class Generator {
public:
    Generator(std::string input_pattern, const Dictionaries& dictionaries);

    const std::string& source() const;
    int count() const;
    const std::vector<Token>& tokens() const;
    std::string get(int index) const;

private:
    std::string source_;
    std::vector<Token> tokens_;
    int count_;
};

}  // namespace wildling
