(function () {
  "use strict";

  var PAGE_SIZE = 100;
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
  var pageEl = document.getElementById("page");
  var pagesEl = document.getElementById("pages");
  var examplesEl = document.getElementById("examples");

  var page = 1;
  var pageCount = 1;
  var debounceTimer = null;

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
      page = 1;
      refresh();
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

  function clampPage(value, max) {
    var n = parseInt(value, 10);
    if (!isFinite(n) || n < 1) n = 1;
    if (n > max) n = max;
    return n;
  }

  function setMeta(total, shown, pages) {
    countEl.textContent = String(total);
    shownEl.textContent = String(shown);
    pagesEl.textContent = String(pages);
    pageEl.max = String(pages);
    pageEl.value = String(page);
  }

  function refresh() {
    var patterns = patternsEl.value
      .split(/\r?\n/)
      .map(function (line) {
        return line.trimEnd();
      })
      .filter(function (line) {
        return line.length > 0;
      });

    if (patterns.length === 0) {
      page = 1;
      pageCount = 1;
      outputEl.value = "";
      setMeta(0, 0, 1);
      return;
    }

    var dictionaries;
    try {
      dictionaries = parseDictionaries(dictsEl.value);
    } catch (err) {
      outputEl.value = "Dictionary JSON error: " + err.message;
      pageCount = 1;
      page = 1;
      setMeta("—", "—", 1);
      return;
    }

    try {
      var w = createWildling({ patterns: patterns, dictionaries: dictionaries });
      var total = w.count();
      pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE) || 1);
      if (total === 0) pageCount = 1;
      page = clampPage(page, pageCount);

      var start = (page - 1) * PAGE_SIZE;
      var end = Math.min(start + PAGE_SIZE, total);
      var lines = [];
      for (var i = start; i < end; i++) {
        var value = w.get(i);
        if (value === false) break;
        lines.push(value);
      }
      setMeta(total, lines.length, pageCount);
      outputEl.value = lines.join("\n");
    } catch (err) {
      outputEl.value = "Error: " + (err && err.message ? err.message : String(err));
      pageCount = 1;
      page = 1;
      setMeta("—", "—", 1);
    }
  }

  function refreshFromInputs() {
    page = 1;
    refresh();
  }

  function scheduleRefresh() {
    if (debounceTimer !== null) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function () {
      debounceTimer = null;
      refreshFromInputs();
    }, 50);
  }

  patternsEl.addEventListener("input", scheduleRefresh);
  dictsEl.addEventListener("input", scheduleRefresh);

  pageEl.addEventListener("change", function () {
    page = clampPage(pageEl.value, pageCount);
    refresh();
  });
  pageEl.addEventListener("keydown", function (ev) {
    if (ev.key === "Enter") {
      ev.preventDefault();
      page = clampPage(pageEl.value, pageCount);
      refresh();
    }
  });

  var params = new URLSearchParams(window.location.search);
  if (params.has("pattern")) {
    patternsEl.value = params.get("pattern");
  }
  refresh();
})();
