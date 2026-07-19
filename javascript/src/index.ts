import createGenerator, {Generator} from "./createGenerator";

export type Dictionaries = {
  [name:string]: string[];
}

export interface WildlingOptions {
  dictionaries: Dictionaries;
  patterns: string[];
}

function generatorsFromPatterns(options: WildlingOptions) {
  const generators: Generator[] = [];
  const hasPatternsOption = options && options.patterns;

  if (hasPatternsOption) {
    options.patterns.forEach(inputPattern => {
      generators.push(createGenerator(inputPattern, options.dictionaries));
    });
  }
  return generators;
}

function calculatePatternCount(generators: Generator[]) {
  let count = 0;

  generators.forEach((generator: Generator) => {
    count += generator.count();
  });
  return count;
}

export default (options: WildlingOptions) => {
  let internalIndex = 0;

  const generators = generatorsFromPatterns(options);
  const patternCount = calculatePatternCount(generators);

  const wildling = {
    index: () => internalIndex,
    count: () => patternCount,
    reset: () => {
      internalIndex = 0;
    },
    next: () => {
      const outOfResults = internalIndex === patternCount;

      if (outOfResults) {
        return false;
      }
      internalIndex += 1;
      return wildling.get(internalIndex - 1);
    },
    generators: () => generators,
    get: (index: number) => {
      let segmentIndex = 0;
      const invalidIndex = index > patternCount - 1 || index < 0;

      if (invalidIndex) {
        return false;
      }
      for (
        const generator of generators
      ) {
        const patternIndex = index - segmentIndex;
        const foundPatternInGenerator = patternIndex < generator.count();

        if (foundPatternInGenerator) {
          return generator.get(patternIndex);
        }
        segmentIndex += generator.count();
      }
      return false; // this will never happen
    }
  };

  return wildling;
};
