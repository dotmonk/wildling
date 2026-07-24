#pragma once

#include "generator.hpp"

#include <optional>
#include <string>
#include <vector>

namespace wildling {

class Wildling {
public:
    static constexpr const char* kVersion = "2.0.5";

    Wildling(const std::vector<std::string>& patterns, const Dictionaries& dictionaries);

    int index() const;
    int count() const;
    void reset();
    std::optional<std::string> next();
    const std::vector<Generator>& generators() const;
    std::optional<std::string> get(int index) const;

private:
    std::vector<Generator> generators_;
    int pattern_count_;
    int internal_index_;
};

}  // namespace wildling
