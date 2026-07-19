#pragma once

#include <string>
#include <vector>
#include <optional>

namespace wildling {

struct TokenOptions {
    std::optional<std::string> string;
    std::optional<int> start_length;
    std::optional<int> end_length;
    std::vector<std::string> variants;
    std::string src;
};

class Token {
public:
    explicit Token(TokenOptions options);

    int count() const;
    const std::string& src() const;
    std::string get(int index) const;

private:
    static int default_integer(std::optional<int> option, int fallback);
    static int pow_int(int base, int exp);

    std::string src_;
    int start_length_;
    int end_length_;
    std::vector<std::string> variants_;
    int count_;
};

}  // namespace wildling
