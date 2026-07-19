function defaultIntegerOption(option: unknown, fallback: unknown) {
  return typeof option === "number" && option >= 0 ? option : fallback;
}

export interface TokenOptions {
  string?: string;
  startLength?: number;
  endLength?: number;
  variants?: string[];
  src: string;
}

export interface Token {
    count: () => number,
    src: () => string,
    get: (index: number) => string;
}

export default function createToken(options:TokenOptions): Token {
  let count = 0;
  const startLength = defaultIntegerOption(options.startLength, 1) as number;
  const endLength = defaultIntegerOption(options.endLength, 1) as number;
  const variants = options.variants || [];

  for (let length = startLength; length <= endLength; length += 1) {
    count += variants.length ** length;
  }

  interface TokenParameters {
      indexWithOffset: number;
      stringLength: number;
    }
  // calculate length of target combination and index for that particular length
  function getTokenParameters(index: number): TokenParameters {
    let stringLength;
    let indexWithOffset;

    indexWithOffset = index;
    for (
      stringLength = startLength;
      stringLength <= endLength;
      stringLength += 1
    ) {
      const offsetCount = variants.length ** stringLength;
      if (indexWithOffset < offsetCount) {
        break;
      } else {
        indexWithOffset -= offsetCount;
      }
    }

    return {
      indexWithOffset,
      stringLength
    };
  }

  function calculateTokenString(tokenParameters: TokenParameters) {
    const stringArray = [];
    const { stringLength } = tokenParameters;
    let { indexWithOffset } = tokenParameters;
    // calculate combination parts
    for (let stringIndex = 0; stringIndex < stringLength; stringIndex += 1) {
      const variantIndex = indexWithOffset % variants.length;
      indexWithOffset = Math.floor(indexWithOffset / variants.length);
      stringArray[stringIndex] = variants[variantIndex];
    }
    return stringArray.join("");
  }

  const token = {
    count: () => count,
    src: () => options.src,
    get: (index:number) => {
      const invalidIndex = index > count - 1 || index < 0;

      if (invalidIndex) {
        return '';
      }

      // special case, zero length string
      if (index === 0 && startLength === 0) {
        return "";
      }

      const tokenParameters = getTokenParameters(index);

      return calculateTokenString(tokenParameters);
    }
  };

  return token;
};
