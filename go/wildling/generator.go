package wildling

// Generator expands a single pattern.
type Generator struct {
	Source string
	tokens []*Token
	count  int
}

// NewGenerator creates a generator for one pattern.
func NewGenerator(inputPattern string, dictionaries Dictionaries) *Generator {
	tokens := ParsePattern(inputPattern, dictionaries)
	count := 1
	for _, token := range tokens {
		count *= token.Count()
	}
	return &Generator{
		Source: inputPattern,
		tokens: tokens,
		count:  count,
	}
}

func (g *Generator) Count() int {
	return g.count
}

func (g *Generator) Tokens() []*Token {
	return g.tokens
}

func (g *Generator) Get(index int) string {
	if index > g.count-1 || index < 0 {
		return ""
	}
	parts := make([]string, len(g.tokens))
	indexWithOffset := index
	for i, token := range g.tokens {
		parts[i] = token.Get(indexWithOffset % token.Count())
		indexWithOffset /= token.Count()
	}
	out := ""
	for _, p := range parts {
		out += p
	}
	return out
}
