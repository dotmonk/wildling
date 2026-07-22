package wildling

// Version is the library/CLI version string.
const Version = "2.0.1"

// Wildling enumerates combinations across one or more patterns.
type Wildling struct {
	generators    []*Generator
	patternCount  int
	internalIndex int
}

// New creates a Wildling from patterns and optional dictionaries.
func New(patterns []string, dictionaries Dictionaries) *Wildling {
	if dictionaries == nil {
		dictionaries = Dictionaries{}
	}
	generators := make([]*Generator, 0, len(patterns))
	total := 0
	for _, pattern := range patterns {
		gen := NewGenerator(pattern, dictionaries)
		generators = append(generators, gen)
		total += gen.Count()
	}
	return &Wildling{
		generators:   generators,
		patternCount: total,
	}
}

func (w *Wildling) Index() int {
	return w.internalIndex
}

func (w *Wildling) Count() int {
	return w.patternCount
}

func (w *Wildling) Reset() {
	w.internalIndex = 0
}

// Next returns the next combination, or false when exhausted.
func (w *Wildling) Next() (string, bool) {
	if w.internalIndex == w.patternCount {
		return "", false
	}
	w.internalIndex++
	return w.Get(w.internalIndex - 1)
}

func (w *Wildling) Generators() []*Generator {
	return w.generators
}

// Get returns the combination at index, or false if out of range.
func (w *Wildling) Get(index int) (string, bool) {
	if index > w.patternCount-1 || index < 0 {
		return "", false
	}
	segmentIndex := 0
	for _, generator := range w.generators {
		patternIndex := index - segmentIndex
		if patternIndex < generator.Count() {
			return generator.Get(patternIndex), true
		}
		segmentIndex += generator.Count()
	}
	return "", false
}
