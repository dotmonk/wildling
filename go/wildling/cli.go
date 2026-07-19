package wildling

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type cliRange struct {
	Start int
	End   int
}

type cliArgs struct {
	Selects      []int
	Ranges       []cliRange
	Check        bool
	Dictionaries Dictionaries
	Patterns     []string
	Help         bool
	Version      bool
}

func parseRange(value string) (cliRange, bool) {
	parts := strings.SplitN(value, "-", 2)
	if len(parts) != 2 {
		return cliRange{}, false
	}
	start, err1 := strconv.Atoi(parts[0])
	end, err2 := strconv.Atoi(parts[1])
	if err1 != nil || err2 != nil || start > end {
		return cliRange{}, false
	}
	// require non-negative digit-only style: Atoi already ok; reject leading signs via original digits check
	for _, p := range parts {
		if p == "" {
			return cliRange{}, false
		}
		for _, c := range p {
			if c < '0' || c > '9' {
				return cliRange{}, false
			}
		}
	}
	return cliRange{Start: start, End: end}, true
}

func loadDictionaryFile(path string) ([]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n")
	out := make([]string, 0, len(lines))
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out, nil
}

func applyDictionary(result *cliArgs, name string, value any) {
	switch v := value.(type) {
	case []any:
		words := make([]string, 0, len(v))
		for _, item := range v {
			words = append(words, fmt.Sprint(item))
		}
		result.Dictionaries[name] = words
	case []string:
		result.Dictionaries[name] = append([]string{}, v...)
	case string:
		if _, err := os.Stat(v); err == nil {
			if words, err := loadDictionaryFile(v); err == nil {
				result.Dictionaries[name] = words
			}
		}
	}
}

type templateFile struct {
	Patterns     []any             `json:"patterns"`
	Dictionaries map[string]any    `json:"dictionaries"`
	Select       []any             `json:"select"`
	Range        []any             `json:"range"`
	Check        *bool             `json:"check"`
}

func applyTemplate(result *cliArgs, path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Template file not found: %s\n", path)
		os.Exit(1)
	}
	var template templateFile
	if err := json.Unmarshal(data, &template); err != nil {
		fmt.Fprintf(os.Stderr, "Invalid JSON template: %s\n", path)
		os.Exit(1)
	}

	if template.Check != nil && *template.Check {
		result.Check = true
	}

	for _, val := range template.Select {
		switch n := val.(type) {
		case float64:
			if int(n) >= 0 {
				result.Selects = append(result.Selects, int(n))
			}
		case string:
			if parsed, err := strconv.Atoi(n); err == nil && parsed >= 0 {
				result.Selects = append(result.Selects, parsed)
			}
		}
	}

	for _, rangeVal := range template.Range {
		if s, ok := rangeVal.(string); ok {
			if parsed, ok := parseRange(s); ok {
				result.Ranges = append(result.Ranges, parsed)
			}
		}
	}

	for name, value := range template.Dictionaries {
		applyDictionary(result, name, value)
	}

	for _, pattern := range template.Patterns {
		result.Patterns = append(result.Patterns, fmt.Sprint(pattern))
	}
}

func parseArgs(args []string) cliArgs {
	result := cliArgs{Dictionaries: Dictionaries{}}
	i := 0
	for i < len(args) {
		arg := args[i]
		switch arg {
		case "--help", "-h":
			result.Help = true
			i++
		case "--version", "-v":
			result.Version = true
			i++
		case "--check":
			result.Check = true
			i++
		case "--select":
			i++
			if i >= len(args) {
				break
			}
			if val, err := strconv.Atoi(args[i]); err == nil && val >= 0 {
				result.Selects = append(result.Selects, val)
			}
			i++
		case "--range":
			i++
			if i >= len(args) {
				break
			}
			if parsed, ok := parseRange(args[i]); ok {
				result.Ranges = append(result.Ranges, parsed)
			}
			i++
		case "--dictionary":
			i++
			if i >= len(args) {
				break
			}
			name, path, found := strings.Cut(args[i], ":")
			if found && name != "" && path != "" {
				applyDictionary(&result, name, path)
			}
			i++
		case "--template":
			i++
			if i >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing path for --template")
				os.Exit(1)
			}
			applyTemplate(&result, args[i])
			i++
		default:
			result.Patterns = append(result.Patterns, arg)
			i++
		}
	}
	return result
}

func loadHelpText() string {
	candidates := []string{}
	if exe, err := os.Executable(); err == nil {
		dir := filepath.Dir(exe)
		candidates = append(candidates,
			filepath.Join(dir, "help.txt"),
			filepath.Join(dir, "..", "docs", "help.txt"),
		)
	}
	candidates = append(candidates, filepath.Join("docs", "help.txt"))

	for _, path := range candidates {
		if data, err := os.ReadFile(path); err == nil {
			return string(data)
		}
	}
	return "wildling - pattern based string generator\n\nHelp text unavailable.\n"
}

func formatList(values []string) string {
	if len(values) == 0 {
		return ""
	}
	return " " + strings.Join(values, " ")
}

func formatCheckOutput(args cliArgs, total int, generators []*Generator) string {
	dictNames := make([]string, 0, len(args.Dictionaries))
	for name := range args.Dictionaries {
		dictNames = append(dictNames, name)
	}
	selects := make([]string, len(args.Selects))
	for i, s := range args.Selects {
		selects[i] = strconv.Itoa(s)
	}
	ranges := make([]string, len(args.Ranges))
	for i, r := range args.Ranges {
		ranges[i] = fmt.Sprintf("%d-%d", r.Start, r.End)
	}

	lines := []string{
		"patterns:" + formatList(args.Patterns),
		"dictionaries:" + formatList(dictNames),
		"select:" + formatList(selects),
		"range:" + formatList(ranges),
		fmt.Sprintf("total: %d", total),
	}
	for _, gen := range generators {
		lines = append(lines, fmt.Sprintf("generator: %s %d", gen.Source, gen.Count()))
	}
	return strings.Join(lines, "\n")
}

// RunCLI executes the shared CLI against argv (excluding program name).
func RunCLI(argv []string) int {
	args := parseArgs(argv)

	if args.Help {
		fmt.Println(strings.TrimRight(loadHelpText(), " \n\r\t"))
		return 0
	}

	if args.Version {
		fmt.Printf("wildling %s\n", Version)
		return 0
	}

	if len(args.Patterns) == 0 {
		fmt.Fprintln(os.Stderr, "No pattern provided. Use --help for usage information.")
		return 1
	}

	wildcard := New(args.Patterns, args.Dictionaries)

	if args.Check {
		fmt.Println(formatCheckOutput(args, wildcard.Count(), wildcard.Generators()))
		return 0
	}

	if len(args.Selects) > 0 || len(args.Ranges) > 0 {
		oor := false
		for _, index := range args.Selects {
			if value, ok := wildcard.Get(index); ok {
				fmt.Println(value)
			} else {
				fmt.Fprintf(os.Stderr, "out of range: %d\n", index)
				oor = true
			}
		}
		for _, r := range args.Ranges {
			for index := r.Start; index <= r.End; index++ {
				if value, ok := wildcard.Get(index); ok {
					fmt.Println(value)
				} else {
					fmt.Fprintf(os.Stderr, "out of range: %d\n", index)
					oor = true
				}
			}
		}
		if oor {
			return 1
		}
		return 0
	}

	for {
		value, ok := wildcard.Next()
		if !ok {
			break
		}
		fmt.Println(value)
	}
	return 0
}
