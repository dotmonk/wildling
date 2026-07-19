package wildling

type tokenOptions struct {
	String      *string
	StartLength *int
	EndLength   *int
	Variants    []string
	Src         string
}

type Token struct {
	src         string
	startLength int
	endLength   int
	variants    []string
	count       int
}

func defaultInteger(option *int, fallback int) int {
	if option != nil && *option >= 0 {
		return *option
	}
	return fallback
}

func powInt(base, exp int) int {
	result := 1
	for i := 0; i < exp; i++ {
		result *= base
	}
	return result
}

func newToken(options tokenOptions) *Token {
	startLength := defaultInteger(options.StartLength, 1)
	endLength := defaultInteger(options.EndLength, 1)
	variants := options.Variants
	if variants == nil {
		variants = []string{}
	}

	count := 0
	for length := startLength; length <= endLength; length++ {
		count += powInt(len(variants), length)
	}

	return &Token{
		src:         options.Src,
		startLength: startLength,
		endLength:   endLength,
		variants:    variants,
		count:       count,
	}
}

func (t *Token) Count() int {
	return t.count
}

func (t *Token) Src() string {
	return t.src
}

func (t *Token) Get(index int) string {
	if index > t.count-1 || index < 0 {
		return ""
	}
	if index == 0 && t.startLength == 0 {
		return ""
	}

	indexWithOffset := index
	stringLength := t.startLength
	for stringLength = t.startLength; stringLength <= t.endLength; stringLength++ {
		offsetCount := powInt(len(t.variants), stringLength)
		if indexWithOffset < offsetCount {
			break
		}
		indexWithOffset -= offsetCount
	}

	parts := make([]string, stringLength)
	for i := 0; i < stringLength; i++ {
		variantIndex := indexWithOffset % len(t.variants)
		indexWithOffset /= len(t.variants)
		parts[i] = t.variants[variantIndex]
	}
	out := ""
	for _, p := range parts {
		out += p
	}
	return out
}
