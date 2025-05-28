'use strict';

var crossFetch = require('cross-fetch');

// This is useful for mocking fetch in tests.
const fetch = crossFetch.fetch;

exports.fetch = fetch;
//# sourceMappingURL=universal.js.map
