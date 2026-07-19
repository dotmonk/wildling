#include "template_json.hpp"

#include <cctype>
#include <stdexcept>
#include <utility>

namespace wildling {

JsonValue::JsonValue() : type_(Type::Null) {}
JsonValue::JsonValue(bool value) : type_(Type::Bool), bool_value_(value) {}
JsonValue::JsonValue(double value) : type_(Type::Number), number_value_(value) {}
JsonValue::JsonValue(std::string value) : type_(Type::String), string_value_(std::move(value)) {}
JsonValue::JsonValue(Array value)
    : type_(Type::Array), array_value_(std::make_unique<Array>(std::move(value))) {}
JsonValue::JsonValue(Object value)
    : type_(Type::Object), object_value_(std::make_unique<Object>(std::move(value))) {}

JsonValue::JsonValue(const JsonValue& other)
    : type_(other.type_),
      bool_value_(other.bool_value_),
      number_value_(other.number_value_),
      string_value_(other.string_value_) {
    if (other.array_value_) {
        array_value_ = std::make_unique<Array>(*other.array_value_);
    }
    if (other.object_value_) {
        object_value_ = std::make_unique<Object>(*other.object_value_);
    }
}

JsonValue::JsonValue(JsonValue&& other) noexcept = default;

JsonValue& JsonValue::operator=(const JsonValue& other) {
    if (this == &other) {
        return *this;
    }
    type_ = other.type_;
    bool_value_ = other.bool_value_;
    number_value_ = other.number_value_;
    string_value_ = other.string_value_;
    array_value_.reset();
    object_value_.reset();
    if (other.array_value_) {
        array_value_ = std::make_unique<Array>(*other.array_value_);
    }
    if (other.object_value_) {
        object_value_ = std::make_unique<Object>(*other.object_value_);
    }
    return *this;
}

JsonValue& JsonValue::operator=(JsonValue&& other) noexcept = default;
JsonValue::~JsonValue() = default;

JsonValue::Type JsonValue::type() const {
    return type_;
}
bool JsonValue::is_null() const {
    return type_ == Type::Null;
}
bool JsonValue::is_bool() const {
    return type_ == Type::Bool;
}
bool JsonValue::is_number() const {
    return type_ == Type::Number;
}
bool JsonValue::is_string() const {
    return type_ == Type::String;
}
bool JsonValue::is_array() const {
    return type_ == Type::Array;
}
bool JsonValue::is_object() const {
    return type_ == Type::Object;
}

bool JsonValue::as_bool() const {
    return bool_value_;
}
double JsonValue::as_number() const {
    return number_value_;
}
const std::string& JsonValue::as_string() const {
    return string_value_;
}
const JsonValue::Array& JsonValue::as_array() const {
    return *array_value_;
}
const JsonValue::Object& JsonValue::as_object() const {
    return *object_value_;
}

namespace {

class Parser {
public:
    explicit Parser(std::string text) : text_(std::move(text)), pos_(0) {}

    JsonValue parse_value() {
        skip_whitespace();
        if (pos_ >= text_.size()) {
            throw std::runtime_error("Unexpected end of JSON");
        }
        char c = text_[pos_];
        if (c == '{') {
            return parse_object_value();
        }
        if (c == '[') {
            return parse_array();
        }
        if (c == '"') {
            return JsonValue(parse_string());
        }
        if (c == 't' || c == 'f') {
            return JsonValue(parse_boolean());
        }
        if (c == 'n') {
            parse_null();
            return JsonValue();
        }
        if (c == '-' || std::isdigit(static_cast<unsigned char>(c))) {
            return JsonValue(parse_number());
        }
        throw std::runtime_error("Unexpected character in JSON");
    }

    void finish() {
        skip_whitespace();
        if (pos_ != text_.size()) {
            throw std::runtime_error("Unexpected trailing JSON content");
        }
    }

private:
    std::string text_;
    size_t pos_;

    void skip_whitespace() {
        while (pos_ < text_.size()) {
            char c = text_[pos_];
            if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
                ++pos_;
            } else {
                break;
            }
        }
    }

    bool peek(char expected) const {
        return pos_ < text_.size() && text_[pos_] == expected;
    }

    void expect(char expected) {
        skip_whitespace();
        if (!peek(expected)) {
            throw std::runtime_error(std::string("Expected '") + expected + "'");
        }
        ++pos_;
    }

    JsonValue parse_object_value() {
        expect('{');
        JsonValue::Object object;
        skip_whitespace();
        if (peek('}')) {
            ++pos_;
            return JsonValue(std::move(object));
        }
        while (true) {
            skip_whitespace();
            std::string key = parse_string();
            skip_whitespace();
            expect(':');
            object.emplace(std::move(key), parse_value());
            skip_whitespace();
            if (peek('}')) {
                ++pos_;
                return JsonValue(std::move(object));
            }
            expect(',');
        }
    }

    JsonValue parse_array() {
        expect('[');
        JsonValue::Array array;
        skip_whitespace();
        if (peek(']')) {
            ++pos_;
            return JsonValue(std::move(array));
        }
        while (true) {
            array.push_back(parse_value());
            skip_whitespace();
            if (peek(']')) {
                ++pos_;
                return JsonValue(std::move(array));
            }
            expect(',');
        }
    }

    std::string parse_string() {
        expect('"');
        std::string out;
        while (pos_ < text_.size()) {
            char c = text_[pos_++];
            if (c == '"') {
                return out;
            }
            if (c == '\\') {
                if (pos_ >= text_.size()) {
                    throw std::runtime_error("Unterminated escape");
                }
                char esc = text_[pos_++];
                switch (esc) {
                    case '"':
                    case '\\':
                    case '/':
                        out.push_back(esc);
                        break;
                    case 'b':
                        out.push_back('\b');
                        break;
                    case 'f':
                        out.push_back('\f');
                        break;
                    case 'n':
                        out.push_back('\n');
                        break;
                    case 'r':
                        out.push_back('\r');
                        break;
                    case 't':
                        out.push_back('\t');
                        break;
                    case 'u': {
                        if (pos_ + 4 > text_.size()) {
                            throw std::runtime_error("Invalid unicode escape");
                        }
                        int code = std::stoi(text_.substr(pos_, 4), nullptr, 16);
                        out.push_back(static_cast<char>(code));
                        pos_ += 4;
                        break;
                    }
                    default:
                        throw std::runtime_error("Invalid escape");
                }
            } else {
                out.push_back(c);
            }
        }
        throw std::runtime_error("Unterminated string");
    }

    double parse_number() {
        size_t start = pos_;
        if (peek('-')) {
            ++pos_;
        }
        while (pos_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[pos_]))) {
            ++pos_;
        }
        if (peek('.')) {
            ++pos_;
            while (pos_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[pos_]))) {
                ++pos_;
            }
        }
        if (pos_ < text_.size() && (text_[pos_] == 'e' || text_[pos_] == 'E')) {
            ++pos_;
            if (peek('+') || peek('-')) {
                ++pos_;
            }
            while (pos_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[pos_]))) {
                ++pos_;
            }
        }
        return std::stod(text_.substr(start, pos_ - start));
    }

    bool parse_boolean() {
        if (text_.compare(pos_, 4, "true") == 0) {
            pos_ += 4;
            return true;
        }
        if (text_.compare(pos_, 5, "false") == 0) {
            pos_ += 5;
            return false;
        }
        throw std::runtime_error("Invalid boolean");
    }

    void parse_null() {
        if (text_.compare(pos_, 4, "null") == 0) {
            pos_ += 4;
            return;
        }
        throw std::runtime_error("Invalid null");
    }
};

}  // namespace

JsonValue JsonValue::parse(const std::string& text) {
    Parser parser(text);
    JsonValue value = parser.parse_value();
    parser.finish();
    return value;
}

JsonValue::Object JsonValue::parse_object(const std::string& text) {
    JsonValue value = parse(text);
    if (!value.is_object()) {
        throw std::runtime_error("Template root must be a JSON object");
    }
    return value.as_object();
}

}  // namespace wildling
