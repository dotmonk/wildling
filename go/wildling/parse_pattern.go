package wildling

import (
	"regexp"
	"strconv"
	"strings"
)

// Dictionaries maps dictionary names to word lists.
type Dictionaries map[string][]string

var (
	tokenParsingRegex      = regexp.MustCompile(`(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])`)
	lengthWithVariantsRegex = regexp.MustCompile(`\{((\d+)-(\d+)|(\d+))\}`)
	lengthWithStringRegex   = regexp.MustCompile(`\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\}`)
)

func parseLengthWithVariants(part string, variants []string) tokenOptions {
	startLength := 1
	endLength := 1

	match := lengthWithVariantsRegex.FindStringSubmatch(part)
	if match != nil {
		if match[2] != "" {
			startLength, _ = strconv.Atoi(match[2])
			endLength, _ = strconv.Atoi(match[3])
		} else if match[1] != "" {
			startLength, _ = strconv.Atoi(match[1])
			endLength = startLength
		}
	}

	return tokenOptions{
		Variants:    variants,
		StartLength: &startLength,
		EndLength:   &endLength,
		Src:         part,
	}
}

func parseLengthWithString(part string) (tokenOptions, bool) {
	match := lengthWithStringRegex.FindStringSubmatch(part)
	if match == nil {
		return tokenOptions{}, false
	}

	s := match[1]
	if match[2] != "" && match[3] != "" {
		start, _ := strconv.Atoi(match[2])
		end, _ := strconv.Atoi(match[3])
		return tokenOptions{
			String:      &s,
			StartLength: &start,
			EndLength:   &end,
			Src:         part,
		}, true
	}

	if match[4] != "" {
		length, _ := strconv.Atoi(match[4])
		return tokenOptions{
			String:      &s,
			StartLength: &length,
			EndLength:   &length,
			Src:         part,
		}, true
	}

	one := 1
	return tokenOptions{
		String:      &s,
		StartLength: &one,
		EndLength:   &one,
		Src:         part,
	}, true
}

func charsAsVariants(variantsString string) []string {
	variants := make([]string, 0, len(variantsString))
	for _, r := range variantsString {
		variants = append(variants, string(r))
	}
	return variants
}

func simpleTokenizer(variantsString string) func(string) *Token {
	variants := charsAsVariants(variantsString)
	return func(part string) *Token {
		return newToken(parseLengthWithVariants(part, variants))
	}
}

func dictionaryTokenizer(part string, dictionaries Dictionaries) *Token {
	options, ok := parseLengthWithString(part)
	if !ok || (options.String != nil && *options.String != "" && !dictHas(dictionaries, *options.String)) {
		one := 1
		return newToken(tokenOptions{
			Variants:    []string{part},
			StartLength: &one,
			EndLength:   &one,
			Src:         part,
		})
	}
	key := ""
	if options.String != nil {
		key = *options.String
	}
	options.Variants = dictionaries[key]
	if options.Variants == nil {
		options.Variants = []string{}
	}
	return newToken(options)
}

func dictHas(dictionaries Dictionaries, key string) bool {
	_, ok := dictionaries[key]
	return ok
}

func wordsTokenizer(part string) *Token {
	options, ok := parseLengthWithString(part)
	if !ok {
		one := 1
		return newToken(tokenOptions{
			Variants:    []string{part},
			StartLength: &one,
			EndLength:   &one,
			Src:         part,
		})
	}

	variants := []string{}
	workString := ""
	if options.String != nil {
		workString = *options.String
	}
	index := 0
	for index < len(workString) {
		if index+1 < len(workString) && workString[index] == '\\' && workString[index+1] == ',' {
			index += 2
		} else if workString[index] == ',' {
			variants = append(variants, workString[:index])
			workString = workString[index+1:]
			index = 0
		} else {
			index++
		}
	}
	variants = append(variants, workString)
	cleaned := make([]string, len(variants))
	for i, v := range variants {
		cleaned[i] = strings.ReplaceAll(v, "\\,", ",")
	}
	options.Variants = cleaned
	return newToken(options)
}

func partToToken(part string, dictionaries Dictionaries) *Token {
	tokenizers := map[byte]func(string) *Token{
		'#': simpleTokenizer("0123456789"),
		'@': simpleTokenizer("abcdefghijklmnopqrstuvwxyz"),
		'*': simpleTokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
		'-': simpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
		'!': simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
		'?': simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
		'&': simpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
		'%': func(p string) *Token { return dictionaryTokenizer(p, dictionaries) },
		'$': wordsTokenizer,
	}

	var tokenizer func(string) *Token
	if len(part) > 0 {
		tokenizer = tokenizers[part[0]]
	}
	isEscaped := len(part) > 1 && part[0] == '\\' && tokenizers[part[1]] != nil

	if tokenizer != nil {
		return tokenizer(part)
	}
	if isEscaped {
		one := 1
		return newToken(tokenOptions{
			Variants:    []string{part[1:]},
			StartLength: &one,
			EndLength:   &one,
			Src:         part,
		})
	}
	one := 1
	return newToken(tokenOptions{
		Variants:    []string{part},
		StartLength: &one,
		EndLength:   &one,
		Src:         part,
	})
}

// ParsePattern splits a pattern into tokens.
func ParsePattern(inputPattern string, dictionaries Dictionaries) []*Token {
	if dictionaries == nil {
		dictionaries = Dictionaries{}
	}
	parts := splitKeepingDelimiters(inputPattern)
	tokens := make([]*Token, 0, len(parts))
	for _, part := range parts {
		if part == "" {
			continue
		}
		tokens = append(tokens, partToToken(part, dictionaries))
	}
	return tokens
}

// Go's regexp.Split does not include capturing-group matches (unlike JS/Python).
func splitKeepingDelimiters(input string) []string {
	indexes := tokenParsingRegex.FindAllStringSubmatchIndex(input, -1)
	if len(indexes) == 0 {
		if input == "" {
			return nil
		}
		return []string{input}
	}

	parts := make([]string, 0, len(indexes)*2+1)
	last := 0
	for _, loc := range indexes {
		// loc[0]:loc[1] full match; loc[2]:loc[3] group 1
		if loc[0] > last {
			parts = append(parts, input[last:loc[0]])
		}
		if loc[2] >= 0 && loc[3] >= loc[2] {
			parts = append(parts, input[loc[2]:loc[3]])
		}
		last = loc[1]
	}
	if last < len(input) {
		parts = append(parts, input[last:])
	}
	return parts
}
