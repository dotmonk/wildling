import { Dictionaries } from ".";
import { Token } from "./createToken";
import parsePattern from "./parsePattern";

export interface Generator {
    source: string;
    count: () => number;
    tokens: () => Token[];
    get: (index:number) => string;
}

export default function createGenerator(inputPattern:string, dictionaries: Dictionaries): Generator {
  let count = 1;
  const tokens = parsePattern(inputPattern, dictionaries);

  tokens.forEach(token => {
    count *= token.count();
  });

  const generator: Generator = {
    source: inputPattern,
    count: () => count,
    tokens: () => tokens,
    get: (index) => {
      const stringArray: string[] = [];
      let indexWithOffset = index;
      const invalidIndex = index > count - 1 || index < 0;

      if (invalidIndex) {
        return '';
      }
      tokens.forEach((token, tokenIndex) => {
        stringArray[tokenIndex] = token.get(indexWithOffset % token.count());
        indexWithOffset = Math.floor(indexWithOffset / token.count());
      });
      return stringArray.join("");
    }
  };

  return generator;
};
