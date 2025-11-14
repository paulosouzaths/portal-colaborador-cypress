// automation/helpers.js
const fs = require('fs');
const path = require('path');

/**
 * Carrega e retorna o JSON do mochawesome.
 * Caminho padrão: cypress/reports/html/mochawesome.json
 */
function loadMochawesomeJson(reportPath = 'cypress/reports/html/mochawesome.json') {
  if (!fs.existsSync(reportPath)) {
    throw new Error(`Arquivo do mochawesome não encontrado em ${reportPath}`);
  }
  const raw = fs.readFileSync(reportPath, 'utf8');
  return JSON.parse(raw);
}

/**
 * Flatten tests from mochawesome structure.
 * Mochawesome pode ter 'results' => 'suites' => nested suites => tests
 */
function extractTestsFromMochawesome(json) {
  const tests = [];

  function walkSuite(suite) {
    if (!suite) return;
    if (Array.isArray(suite.tests)) {
      suite.tests.forEach(t => tests.push(t));
    }
    if (Array.isArray(suite.suites)) {
      suite.suites.forEach(walkSuite);
    }
  }

  // two common shapes: json.results (array) or json (suite)
  if (Array.isArray(json.results)) {
    json.results.forEach(r => {
      if (r.suites) walkSuite(r.suites);
      if (r.tests) r.tests.forEach(t => tests.push(t));
    });
  } else {
    // fallback: try top-level suites
    if (json.suites) {
      walkSuite(json.suites);
    }
    if (json.tests) {
      json.tests.forEach(t => tests.push(t));
    }
  }
  return tests;
}

/**
 * Procura screenshots correspondentes no disco.
 * Estratégia:
 *  - Se o objeto test tiver `screenshots` com paths, usa elas.
 *  - Senão, procura em cypress/screenshots por arquivos que contenham o teste (title) ou o screenshot name.
 */
function findScreenshotsForTest(testObj, screenshotsRoot = 'cypress/screenshots') {
  const found = [];

  // 1) mochawesome test object sometimes has screenshots array
  if (testObj.screenshots && Array.isArray(testObj.screenshots) && testObj.screenshots.length) {
    for (const s of testObj.screenshots) {
      // s can be a path or dataURL; try to detect
      if (s.path && fs.existsSync(s.path)) {
        found.push(s.path);
      } else {
        // try common relative path: cypress/screenshots/<spec>/<name>.png
        const candidate = path.join(screenshotsRoot, s);
        if (fs.existsSync(candidate)) found.push(candidate);
      }
    }
  }

  // 2) try to match file names in screenshots folder containing test title / test.fullTitle / screenshot name
  const searchNames = [];
  if (testObj.fullTitle) searchNames.push(testObj.fullTitle);
  if (testObj.title) searchNames.push(testObj.title);
  if (testObj.titlePath && Array.isArray(testObj.titlePath)) searchNames.push(testObj.titlePath.join(' '));

  // sanitize to smaller substrings (avoid punctuation noise)
  const sanitized = searchNames
    .filter(Boolean)
    .map(s => s.replace(/[:\/\\|<>?"'*]/g, '').trim().toLowerCase());

  // walk screenshotsRoot recursively and find matches
  function walk(dir) {
    if (!fs.existsSync(dir)) return;
    const entries = fs.readdirSync(dir);
    for (const e of entries) {
      const full = path.join(dir, e);
      const stat = fs.statSync(full);
      if (stat.isDirectory()) {
        walk(full);
      } else {
        const nameLower = e.toLowerCase();
        for (const s of sanitized) {
          // match if screenshot filename contains substr of the test title (or whole title)
          if (!s) continue;
          if (nameLower.includes(s) || s.includes(nameLower) || nameLower.includes(s.split(' ').slice(0,4).join(' '))) {
            found.push(full);
            break;
          }
        }
      }
    }
  }

  walk(screenshotsRoot);

  // unique
  return Array.from(new Set(found));
}

module.exports = {
  loadMochawesomeJson,
  extractTestsFromMochawesome,
  findScreenshotsForTest
};
