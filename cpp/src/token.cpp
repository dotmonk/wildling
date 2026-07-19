#include "token.hpp"

namespace wildling {

int Token::default_integer(std::optional<int> option, int fallback) {
    return option.has_value() && option.value() >= 0 ? option.value() : fallback;
}

int Token::pow_int(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; ++i) {
        result *= base;
    }
    return result;
}

Token::Token(TokenOptions options)
    : src_(std::move(options.src)),
      start_length_(default_integer(options.start_length, 1)),
      end_length_(default_integer(options.end_length, 1)),
      variants_(std::move(options.variants)),
      count_(0) {
    for (int length = start_length_; length <= end_length_; ++length) {
        count_ += pow_int(static_cast<int>(variants_.size()), length);
    }
}

int Token::count() const {
    return count_;
}

const std::string& Token::src() const {
    return src_;
}

std::string Token::get(int index) const {
    if (index > count_ - 1 || index < 0) {
        return "";
    }
    if (index == 0 && start_length_ == 0) {
        return "";
    }

    int index_with_offset = index;
    int string_length = start_length_;
    for (string_length = start_length_; string_length <= end_length_; ++string_length) {
        int offset_count = pow_int(static_cast<int>(variants_.size()), string_length);
        if (index_with_offset < offset_count) {
            break;
        }
        index_with_offset -= offset_count;
    }

    std::string out;
    out.reserve(static_cast<size_t>(string_length) * 4);
    for (int i = 0; i < string_length; ++i) {
        int variant_index = index_with_offset % static_cast<int>(variants_.size());
        index_with_offset /= static_cast<int>(variants_.size());
        out += variants_[static_cast<size_t>(variant_index)];
    }
    return out;
}

}  // namespace wildling
