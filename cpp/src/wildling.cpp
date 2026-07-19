#include "wildling.hpp"

namespace wildling {

Wildling::Wildling(const std::vector<std::string>& patterns, const Dictionaries& dictionaries)
    : pattern_count_(0), internal_index_(0) {
    for (const auto& pattern : patterns) {
        generators_.emplace_back(pattern, dictionaries);
        pattern_count_ += generators_.back().count();
    }
}

int Wildling::index() const {
    return internal_index_;
}

int Wildling::count() const {
    return pattern_count_;
}

void Wildling::reset() {
    internal_index_ = 0;
}

std::optional<std::string> Wildling::next() {
    if (internal_index_ == pattern_count_) {
        return std::nullopt;
    }
    ++internal_index_;
    return get(internal_index_ - 1);
}

const std::vector<Generator>& Wildling::generators() const {
    return generators_;
}

std::optional<std::string> Wildling::get(int index) const {
    if (index > pattern_count_ - 1 || index < 0) {
        return std::nullopt;
    }
    int segment_index = 0;
    for (const auto& generator : generators_) {
        int pattern_index = index - segment_index;
        if (pattern_index < generator.count()) {
            return generator.get(pattern_index);
        }
        segment_index += generator.count();
    }
    return std::nullopt;
}

}  // namespace wildling
