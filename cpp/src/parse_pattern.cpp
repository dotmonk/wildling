#include "parse_pattern.hpp"

#include <cctype>
#include <functional>
#include <regex>
#include <utility>

namespace wildling {
namespace {

const std::regex& token_parsing_regex() {
    // Use [^}]* instead of .*? — more reliable with libstdc++ ECMAScript.
    static const std::regex re(
        R"((\\[%@$*#&?!-]|[%@$*#&?!-]\{[^}]*\}|[%@$*#&?!-]))");
    return re;
}

const std::regex& length_with_variants_regex() {
    static const std::regex re(R"(\{((\d+)-(\d+)|(\d+))\})");
    return re;
}

const std::regex& length_with_string_regex() {
    static const std::regex re(R"(\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\})");
    return re;
}

TokenOptions parse_length_with_variants(const std::string& part, std::vector<std::string> variants) {
    std::smatch match;
    int start_length = 1;
    int end_length = 1;

    if (std::regex_search(part, match, length_with_variants_regex())) {
        if (match[2].matched && match[2].length() > 0) {
            start_length = std::stoi(match[2].str());
            end_length = std::stoi(match[3].str());
        } else if (match[1].matched) {
            start_length = std::stoi(match[1].str());
            end_length = start_length;
        }
    }

    TokenOptions options;
    options.variants = std::move(variants);
    options.start_length = start_length;
    options.end_length = end_length;
    options.src = part;
    return options;
}

std::optional<TokenOptions> parse_length_with_string(const std::string& part) {
    std::smatch match;
    if (!std::regex_search(part, match, length_with_string_regex())) {
        return std::nullopt;
    }

    TokenOptions options;
    options.src = part;
    options.string = match[1].matched ? match[1].str() : "";

    if (match[2].matched && match[3].matched) {
        options.start_length = std::stoi(match[2].str());
        options.end_length = std::stoi(match[3].str());
        return options;
    }

    if (match[4].matched) {
        int length = std::stoi(match[4].str());
        options.start_length = length;
        options.end_length = length;
        return options;
    }

    options.start_length = 1;
    options.end_length = 1;
    return options;
}

std::vector<std::string> chars_as_variants(const std::string& variants_string) {
    std::vector<std::string> variants;
    variants.reserve(variants_string.size());
    for (char c : variants_string) {
        variants.emplace_back(1, c);
    }
    return variants;
}

Token dictionary_tokenizer(const std::string& part, const Dictionaries& dictionaries) {
    auto options = parse_length_with_string(part);
    if (!options.has_value()
        || (options->string.has_value() && !options->string->empty()
            && dictionaries.find(*options->string) == dictionaries.end())) {
        TokenOptions literal;
        literal.variants = {part};
        literal.start_length = 1;
        literal.end_length = 1;
        literal.src = part;
        return Token(std::move(literal));
    }

    const std::string key = options->string.value_or("");
    auto it = dictionaries.find(key);
    options->variants = it != dictionaries.end() ? it->second : std::vector<std::string>{};
    return Token(std::move(*options));
}

Token words_tokenizer(const std::string& part) {
    auto options = parse_length_with_string(part);
    if (!options.has_value()) {
        TokenOptions literal;
        literal.variants = {part};
        literal.start_length = 1;
        literal.end_length = 1;
        literal.src = part;
        return Token(std::move(literal));
    }

    std::vector<std::string> variants;
    std::string work_string = options->string.value_or("");
    size_t index = 0;
    while (index < work_string.size()) {
        if (index + 1 < work_string.size() && work_string[index] == '\\' && work_string[index + 1] == ',') {
            index += 2;
        } else if (work_string[index] == ',') {
            variants.push_back(work_string.substr(0, index));
            work_string = work_string.substr(index + 1);
            index = 0;
        } else {
            ++index;
        }
    }
    variants.push_back(work_string);
    for (auto& variant : variants) {
        size_t pos = 0;
        while ((pos = variant.find("\\,", pos)) != std::string::npos) {
            variant.replace(pos, 2, ",");
            pos += 1;
        }
    }
    options->variants = std::move(variants);
    return Token(std::move(*options));
}

std::vector<std::string> split_keeping_delimiters(const std::string& input) {
    std::vector<std::string> parts;
    const std::regex& re = token_parsing_regex();
    auto begin = std::sregex_iterator(input.begin(), input.end(), re);
    auto end = std::sregex_iterator();
    size_t last = 0;
    for (auto it = begin; it != end; ++it) {
        const std::smatch& match = *it;
        if (static_cast<size_t>(match.position()) > last) {
            parts.push_back(input.substr(last, static_cast<size_t>(match.position()) - last));
        }
        parts.push_back(match.str(1));
        last = static_cast<size_t>(match.position() + match.length());
    }
    if (last < input.size()) {
        parts.push_back(input.substr(last));
    }
    return parts;
}

Token part_to_token(const std::string& part, const Dictionaries& dictionaries) {
    using Tokenizer = std::function<Token(const std::string&)>;
    std::map<char, Tokenizer> tokenizers;
    tokenizers['#'] = [](const std::string& p) {
        return Token(parse_length_with_variants(p, chars_as_variants("0123456789")));
    };
    tokenizers['@'] = [](const std::string& p) {
        return Token(parse_length_with_variants(p, chars_as_variants("abcdefghijklmnopqrstuvwxyz")));
    };
    tokenizers['*'] = [](const std::string& p) {
        return Token(parse_length_with_variants(
            p, chars_as_variants("abcdefghijklmnopqrstuvwxyz0123456789")));
    };
    tokenizers['-'] = [](const std::string& p) {
        return Token(parse_length_with_variants(
            p,
            chars_as_variants(
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")));
    };
    tokenizers['!'] = [](const std::string& p) {
        return Token(parse_length_with_variants(p, chars_as_variants("ABCDEFGHIJKLMNOPQRSTUVWXYZ")));
    };
    tokenizers['?'] = [](const std::string& p) {
        return Token(parse_length_with_variants(
            p, chars_as_variants("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")));
    };
    tokenizers['&'] = [](const std::string& p) {
        return Token(parse_length_with_variants(
            p, chars_as_variants("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")));
    };
    tokenizers['%'] = [&dictionaries](const std::string& p) {
        return dictionary_tokenizer(p, dictionaries);
    };
    tokenizers['$'] = [](const std::string& p) { return words_tokenizer(p); };

    Tokenizer* tokenizer = nullptr;
    if (!part.empty()) {
        auto it = tokenizers.find(part[0]);
        if (it != tokenizers.end()) {
            tokenizer = &it->second;
        }
    }

    const bool is_escaped = part.size() > 1 && part[0] == '\\'
        && tokenizers.find(part[1]) != tokenizers.end();

    if (tokenizer != nullptr) {
        return (*tokenizer)(part);
    }
    if (is_escaped) {
        TokenOptions options;
        options.variants = {part.substr(1)};
        options.start_length = 1;
        options.end_length = 1;
        options.src = part;
        return Token(std::move(options));
    }

    TokenOptions options;
    options.variants = {part};
    options.start_length = 1;
    options.end_length = 1;
    options.src = part;
    return Token(std::move(options));
}

}  // namespace

std::vector<Token> parse_pattern(const std::string& input_pattern, const Dictionaries& dictionaries) {
    std::vector<Token> tokens;
    for (const auto& part : split_keeping_delimiters(input_pattern)) {
        if (!part.empty()) {
            tokens.push_back(part_to_token(part, dictionaries));
        }
    }
    return tokens;
}

}  // namespace wildling
