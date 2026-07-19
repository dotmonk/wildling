import { Dictionaries } from ".";
import createToken, { Token, TokenOptions } from "./createToken";

const tokenParsingRegex = /(\\[%@$*#&?!-]{1}|[%@$*#&?!-]{1}\{.*?\}|[%@$*#&?!-]{1})(?=.*)/g;

function parseLengthWithVariants(part: string, variants: string[]) {
  const lengthArgRegex = /\{((\d+)-(\d+)|(\d+))\}/;
  const match = lengthArgRegex.exec(part);
  const partStringHasRangeParameters = match !== null && match[2];
  const partStringHasLengthParameter = match !== null && match[1];

  let startLength = 1;
  let endLength = 1;

  if (partStringHasRangeParameters) {
    startLength = match[2] ? parseInt(match[2]) : 0;
    endLength = match[3] ? parseInt(match[3]) : 0;
  } else if (partStringHasLengthParameter) {
    startLength = match[1] ? parseInt(match[1]) : 0;
    endLength = startLength;
  }

  return {
    variants,
    startLength,
    endLength,
    src: part
  };
}

function parseLengthWithString(part: string): TokenOptions | false {
  const lengthArgRegex = /\{'(.*)'(,(\d+)-(\d+)){0,1}(,(\d+)){0,1}\}/;
  const match = lengthArgRegex.exec(part);
  const partStringHasRangeParameters = match !== null && match[3] && match[4];
  const partStringHasLengthParameter = match !== null && match[6];

  if (partStringHasRangeParameters) {
    return {
      string: match[1] || '',
      startLength: match[3] ? parseInt(match[3]) : 0,
      endLength: match[4] ? parseInt(match[4]) : 0,
      src: part
    };
  }
  if (partStringHasLengthParameter) {
    const length = match[6] ? parseInt(match[6]) : 0;

    return {
      string: match[1] || '',
      startLength: length,
      endLength: length,
      src: part
    };
  }
  if (match !== null) {
    return {
      string: match[1] || '',
      startLength: 1,
      endLength: 1,
      src: part
    };
  }
  return false;
}

function simpleTokenizer(variantsString: string) {
  const variants = variantsString.split("");

  return (part: string) => {
    const options = parseLengthWithVariants(part, variants);

    return createToken(options);
  };
}

interface Tokenizers { [token: string]: (part: string) => Token };

function partToToken(part: string, dictionaries: Dictionaries) {
  const tokenizers: Tokenizers = {
    // 0-9
    "#": simpleTokenizer("0123456789"),
    // a-z
    "@": simpleTokenizer("abcdefghijklmnopqrstuvwxyz"),
    // a-z0-9
    "*": simpleTokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
    // a-zA-Z0-9
    "-": simpleTokenizer(
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    ),
    // A-Z
    "!": simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    // A-Z0-9
    "?": simpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
    // a-zA-Z
    "&": simpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    // dictionary
    "%": (part: string) => {
      let options = parseLengthWithString(part);
      if (!options || (options.string && !(options.string in dictionaries))) {
        options = {
          variants: [part],
          startLength: 1,
          endLength: 1,
          src: part
        };
      } else {
        options.variants = dictionaries[options.string || ''] || [];
      }

      return createToken(options);
    },
    // special chars/words ${'<comma separated list
    // with \' as "'" mark'[,length | ,length-length]}
    $: (part: string) => {
      let options = parseLengthWithString(part);

      if (options === false) {
        options = {
          variants: [part],
          startLength: 1,
          endLength: 1,
          src: part
        };
      } else {
        const variants = [];
        let workString = options.string || '';
        let index = 0;
        do {
          if (workString.substr(index, 2) === "\\,") {
            index += 2;
          } else if (workString[index] === ",") {
            variants.push(workString.substr(0, index));
            workString = workString.substr(index + 1);
            index = 0;
          } else {
            index += 1;
          }
        } while (index < workString.length);
        variants.push(workString);
        options.variants = variants.map(variant => variant.replace("\\,", ","));
      }

      return createToken(options);
    }
  };
  const tokenizer = part[0] !== undefined && part[0] in tokenizers ? tokenizers[part[0]] : null;
  const isEscapedToken =
    part.length > 1 && part[0] === "\\" && part[1] !== undefined && part[1] in tokenizers;
  let token;

  if (tokenizer) {
    token = tokenizer(part);
  } else if (isEscapedToken) {
    token = createToken({
      variants: [part.replace(/^\\/, "")],
      src: part
    });
  } else {
    token = createToken({
      variants: [part],
      src: part
    });
  }

  return token;
}

export default function parsePattern(inputPattern: string, dictionaries: Dictionaries): Token[] {
  const tokens: Token[] = [];
  const parts = inputPattern.split(tokenParsingRegex).filter(Boolean);

  parts.forEach(part => tokens.push(partToToken(part, dictionaries)));

  return tokens;
};
