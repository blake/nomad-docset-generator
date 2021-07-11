#!/usr/bin/env node

// Reads website redirects from redirects.js and outputs a JSON object with
// the source path as key, and the destination path as the value.
// For example:
// {
//   '/original/path/to/file': '/new/path/to/file'
// }
// This is used later when building the site to ensure that URLs always point to
// the correct content.

let redirect_file = process.argv[2];

redirects = require(redirect_file);

redirects_obj = {}

redirects.forEach(r => {
  redirects_obj[r.source] = r.destination;
});

console.log(JSON.stringify(redirects_obj));
