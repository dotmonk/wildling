#include "generator.hpp"

namespace wildling {

Generator::Generator(std::string input_pattern, const Dictionaries& dictionaries)
    : source_(std::move(input_pattern)),
      tokens_(parse_pattern(source_, dictionaries)),
      count_(1) {
    for (const auto& token : tokens_) {
        count_ *= token.count();
    }
}

const std::string& Generator::source() const {
    return source_;
}

int Generator::count() const {
    return count_;
}

const std::vector<Token>& Generator::tokens() const {
    return tokens_;
}

std::string Generator::get(int index) const {
    if (index > count_ - 1 || index < 0) {
        return "";
    }
    std::string out;
    int index_with_offset = index;
    for (const auto& token : tokens_) {
        out += token.get(index_with_offset % token.count());
        index_with_offset /= token.count();
    }
    return out;
}

}  // namespace wildling
