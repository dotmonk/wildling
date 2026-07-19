#include "template_json.hpp"
#include "wildling.hpp"

#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace fs = std::filesystem;

namespace {

struct Range {
    int start;
    int end;
};

struct CliArgs {
    std::vector<int> selects;
    std::vector<Range> ranges;
    bool check = false;
    wildling::Dictionaries dictionaries;
    std::vector<std::string> patterns;
    bool help = false;
    bool version = false;
};

bool is_digits(const std::string& value) {
    if (value.empty()) {
        return false;
    }
    for (char c : value) {
        if (!std::isdigit(static_cast<unsigned char>(c))) {
            return false;
        }
    }
    return true;
}

std::optional<Range> parse_range(const std::string& value) {
    auto dash = value.find('-');
    if (dash == std::string::npos || dash == 0 || dash == value.size() - 1) {
        return std::nullopt;
    }
    std::string left = value.substr(0, dash);
    std::string right = value.substr(dash + 1);
    if (!is_digits(left) || !is_digits(right)) {
        return std::nullopt;
    }
    int start = std::stoi(left);
    int end = std::stoi(right);
    if (start > end) {
        return std::nullopt;
    }
    return Range{start, end};
}

std::vector<std::string> load_dictionary_file(const std::string& path) {
    std::ifstream in(path);
    std::vector<std::string> lines;
    std::string line;
    while (std::getline(in, line)) {
        // trim
        size_t start = 0;
        while (start < line.size() && std::isspace(static_cast<unsigned char>(line[start]))) {
            ++start;
        }
        size_t end = line.size();
        while (end > start && std::isspace(static_cast<unsigned char>(line[end - 1]))) {
            --end;
        }
        if (end > start) {
            lines.push_back(line.substr(start, end - start));
        }
    }
    return lines;
}

void apply_dictionary(CliArgs& result, const std::string& name, const wildling::JsonValue& value) {
    if (value.is_array()) {
        std::vector<std::string> words;
        for (const auto& item : value.as_array()) {
            if (item.is_string()) {
                words.push_back(item.as_string());
            } else if (item.is_number()) {
                words.push_back(std::to_string(static_cast<long long>(item.as_number())));
            } else if (item.is_bool()) {
                words.push_back(item.as_bool() ? "true" : "false");
            }
        }
        result.dictionaries[name] = std::move(words);
        return;
    }

    if (value.is_string()) {
        const std::string& path = value.as_string();
        if (fs::exists(path)) {
            try {
                result.dictionaries[name] = load_dictionary_file(path);
            } catch (...) {
                // ignore unreadable dictionary files
            }
        }
    }
}

void apply_dictionary_path(CliArgs& result, const std::string& name, const std::string& path) {
    if (fs::exists(path)) {
        try {
            result.dictionaries[name] = load_dictionary_file(path);
        } catch (...) {
            // ignore
        }
    }
}

void apply_template(CliArgs& result, const std::string& path) {
    if (!fs::exists(path)) {
        std::cerr << "Template file not found: " << path << '\n';
        std::exit(1);
    }

    wildling::JsonValue::Object template_obj;
    try {
        std::ifstream in(path);
        std::ostringstream ss;
        ss << in.rdbuf();
        template_obj = wildling::JsonValue::parse_object(ss.str());
    } catch (...) {
        std::cerr << "Invalid JSON template: " << path << '\n';
        std::exit(1);
    }

    auto check_it = template_obj.find("check");
    if (check_it != template_obj.end() && check_it->second.is_bool() && check_it->second.as_bool()) {
        result.check = true;
    }

    auto select_it = template_obj.find("select");
    if (select_it != template_obj.end() && select_it->second.is_array()) {
        for (const auto& val : select_it->second.as_array()) {
            try {
                int number = -1;
                if (val.is_number()) {
                    number = static_cast<int>(val.as_number());
                } else if (val.is_string()) {
                    number = std::stoi(val.as_string());
                }
                if (number >= 0) {
                    result.selects.push_back(number);
                }
            } catch (...) {
                // skip invalid
            }
        }
    }

    auto range_it = template_obj.find("range");
    if (range_it != template_obj.end() && range_it->second.is_array()) {
        for (const auto& range_val : range_it->second.as_array()) {
            std::string range_str;
            if (range_val.is_string()) {
                range_str = range_val.as_string();
            } else {
                continue;
            }
            auto parsed = parse_range(range_str);
            if (parsed.has_value()) {
                result.ranges.push_back(*parsed);
            }
        }
    }

    auto dict_it = template_obj.find("dictionaries");
    if (dict_it != template_obj.end() && dict_it->second.is_object()) {
        for (const auto& entry : dict_it->second.as_object()) {
            apply_dictionary(result, entry.first, entry.second);
        }
    }

    auto patterns_it = template_obj.find("patterns");
    if (patterns_it != template_obj.end() && patterns_it->second.is_array()) {
        for (const auto& pattern : patterns_it->second.as_array()) {
            if (pattern.is_string()) {
                result.patterns.push_back(pattern.as_string());
            }
        }
    }
}

CliArgs parse_args(const std::vector<std::string>& args) {
    CliArgs result;
    size_t i = 0;
    while (i < args.size()) {
        const std::string& arg = args[i];

        if (arg == "--help" || arg == "-h") {
            result.help = true;
            ++i;
            continue;
        }
        if (arg == "--version" || arg == "-v") {
            result.version = true;
            ++i;
            continue;
        }
        if (arg == "--check") {
            result.check = true;
            ++i;
            continue;
        }
        if (arg == "--select") {
            ++i;
            if (i >= args.size()) {
                break;
            }
            try {
                int val = std::stoi(args[i]);
                if (val >= 0) {
                    result.selects.push_back(val);
                }
            } catch (...) {
                // skip
            }
            ++i;
            continue;
        }
        if (arg == "--range") {
            ++i;
            if (i >= args.size()) {
                break;
            }
            auto parsed = parse_range(args[i]);
            if (parsed.has_value()) {
                result.ranges.push_back(*parsed);
            }
            ++i;
            continue;
        }
        if (arg == "--dictionary") {
            ++i;
            if (i >= args.size()) {
                break;
            }
            auto colon = args[i].find(':');
            if (colon != std::string::npos && colon > 0 && colon + 1 < args[i].size()) {
                apply_dictionary_path(result, args[i].substr(0, colon), args[i].substr(colon + 1));
            }
            ++i;
            continue;
        }
        if (arg == "--template") {
            ++i;
            if (i >= args.size()) {
                std::cerr << "Missing path for --template\n";
                std::exit(1);
            }
            apply_template(result, args[i]);
            ++i;
            continue;
        }

        result.patterns.push_back(arg);
        ++i;
    }
    return result;
}

std::string load_help_text(const std::string& argv0) {
    std::vector<fs::path> candidates;
    fs::path base = fs::path(argv0).parent_path();
    if (!base.empty()) {
        candidates.push_back(base / "help.txt");
        candidates.push_back(base / ".." / "docs" / "help.txt");
    }
    candidates.push_back("docs/help.txt");

    for (const auto& path : candidates) {
        std::error_code ec;
        if (fs::exists(path, ec)) {
            std::ifstream in(path);
            if (in) {
                std::ostringstream ss;
                ss << in.rdbuf();
                return ss.str();
            }
        }
    }
    return "wildling - pattern based string generator\n\nHelp text unavailable.\n";
}

std::string format_list(const std::vector<std::string>& values) {
    if (values.empty()) {
        return "";
    }
    std::ostringstream ss;
    ss << ' ';
    for (size_t i = 0; i < values.size(); ++i) {
        if (i > 0) {
            ss << ' ';
        }
        ss << values[i];
    }
    return ss.str();
}

std::string format_check_output(const CliArgs& args, int total, const std::vector<wildling::Generator>& generators) {
    std::vector<std::string> dict_names;
    for (const auto& entry : args.dictionaries) {
        dict_names.push_back(entry.first);
    }
    std::vector<std::string> selects;
    for (int s : args.selects) {
        selects.push_back(std::to_string(s));
    }
    std::vector<std::string> ranges;
    for (const auto& r : args.ranges) {
        ranges.push_back(std::to_string(r.start) + "-" + std::to_string(r.end));
    }

    std::ostringstream out;
    out << "patterns:" << format_list(args.patterns) << '\n';
    out << "dictionaries:" << format_list(dict_names) << '\n';
    out << "select:" << format_list(selects) << '\n';
    out << "range:" << format_list(ranges) << '\n';
    out << "total: " << total;
    for (const auto& gen : generators) {
        out << '\n' << "generator: " << gen.source() << ' ' << gen.count();
    }
    return out.str();
}

std::string rtrim(std::string text) {
    while (!text.empty() && (text.back() == ' ' || text.back() == '\n' || text.back() == '\r' || text.back() == '\t')) {
        text.pop_back();
    }
    return text;
}

}  // namespace

int main(int argc, char** argv) {
    std::vector<std::string> args;
    args.reserve(static_cast<size_t>(argc > 0 ? argc - 1 : 0));
    for (int i = 1; i < argc; ++i) {
        args.emplace_back(argv[i]);
    }

    CliArgs parsed = parse_args(args);
    std::string argv0 = argc > 0 ? argv[0] : "wildling";

    if (parsed.help) {
        std::cout << rtrim(load_help_text(argv0)) << '\n';
        return 0;
    }

    if (parsed.version) {
        std::cout << "wildling " << wildling::Wildling::kVersion << '\n';
        return 0;
    }

    if (parsed.patterns.empty()) {
        std::cerr << "No pattern provided. Use --help for usage information.\n";
        return 1;
    }

    wildling::Wildling wildcard(parsed.patterns, parsed.dictionaries);

    if (parsed.check) {
        std::cout << format_check_output(parsed, wildcard.count(), wildcard.generators()) << '\n';
        return 0;
    }

    if (!parsed.selects.empty() || !parsed.ranges.empty()) {
        for (int index : parsed.selects) {
            auto value = wildcard.get(index);
            if (value.has_value()) {
                std::cout << *value << '\n';
            } else {
                std::cout << "false\n";
            }
        }
        for (const auto& range : parsed.ranges) {
            for (int index = range.start; index <= range.end; ++index) {
                auto value = wildcard.get(index);
                if (value.has_value()) {
                    std::cout << *value << '\n';
                } else {
                    std::cout << "false\n";
                }
            }
        }
        return 0;
    }

    auto value = wildcard.next();
    while (value.has_value()) {
        std::cout << *value << '\n';
        value = wildcard.next();
    }

    return 0;
}
