(function () {
  "use strict";

  var MAX_LINES = 500;
  var createWildling = window.wildling;
  if (typeof createWildling !== "function") {
    document.getElementById("output").value =
      "wildling bundle missing — run scripts/build-site.sh";
    return;
  }

  var patternsEl = document.getElementById("patterns");
  var dictsEl = document.getElementById("dictionaries");
  var outputEl = document.getElementById("output");
  var countEl = document.getElementById("count");
  var shownEl = document.getElementById("shown");
  var examplesEl = document.getElementById("examples");

  var EXAMPLES = [
    { label: "foo#", patterns: "foo#" },
    { label: "@{1-2}", patterns: "@{1-2}" },
    { label: "!!", patterns: "!!" },
    { label: "words", patterns: "${'blue,red,green',1-2}" },
    { label: "dict", patterns: "%{'colors'}#" },
    { label: "multi", patterns: "abrakadabra\nfoo#" },
    { label: "escape", patterns: "\\##" },
  ];

  EXAMPLES.forEach(function (ex) {
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "chip";
    btn.textContent = ex.label;
    btn.addEventListener("click", function () {
      patternsEl.value = ex.patterns;
      run();
    });
    examplesEl.appendChild(btn);
  });

  function parseDictionaries(text) {
    var trimmed = text.trim();
    if (!trimmed) return {};
    var parsed = JSON.parse(trimmed);
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("Dictionaries must be a JSON object");
    }
    var out = {};
    Object.keys(parsed).forEach(function (key) {
      var val = parsed[key];
      if (!Array.isArray(val)) {
        throw new Error('Dictionary "' + key + '" must be an array of strings');
      }
      out[key] = val.map(String);
    });
    return out;
  }

  function run() {
    var patterns = patternsEl.value
      .split(/\r?\n/)
      .map(function (line) {
        return line.trimEnd();
      })
      .filter(function (line) {
        return line.length > 0;
      });

    if (patterns.length === 0) {
      outputEl.value = "";
      countEl.textContent = "0";
      shownEl.textContent = "0";
      return;
    }

    var dictionaries;
    try {
      dictionaries = parseDictionaries(dictsEl.value);
    } catch (err) {
      outputEl.value = "Dictionary JSON error: " + err.message;
      countEl.textContent = "—";
      shownEl.textContent = "—";
      return;
    }

    try {
      var w = createWildling({ patterns: patterns, dictionaries: dictionaries });
      var total = w.count();
      countEl.textContent = String(total);
      var lines = [];
      var n = Math.min(total, MAX_LINES);
      for (var i = 0; i < n; i++) {
        var value = w.get(i);
        if (value === false) break;
        lines.push(value);
      }
      shownEl.textContent = String(lines.length);
      if (total > MAX_LINES) {
        lines.push("… (" + (total - MAX_LINES) + " more)");
      }
      outputEl.value = lines.join("\n");
    } catch (err) {
      outputEl.value = "Error: " + (err && err.message ? err.message : String(err));
      countEl.textContent = "—";
      shownEl.textContent = "—";
    }
  }

  document.getElementById("run").addEventListener("click", run);
  patternsEl.addEventListener("keydown", function (ev) {
    if ((ev.metaKey || ev.ctrlKey) && ev.key === "Enter") {
      ev.preventDefault();
      run();
    }
  });

  var params = new URLSearchParams(window.location.search);
  if (params.has("pattern")) {
    patternsEl.value = params.get("pattern");
  }
  run();
})();
