const fs = require('fs');
const path = require('path');

module.exports = function (eleventyConfig) {
  // Copy static assets through unchanged.
  eleventyConfig.addPassthroughCopy('img');
  eleventyConfig.addPassthroughCopy({ '../assets/logo.svg': 'assets/logo.svg' });

  // Global data: version from VERSION file in project root.
  eleventyConfig.addGlobalData('version', (() => {
    try {
      return fs.readFileSync(path.join(__dirname, '..', 'VERSION'), 'utf8').trim();
    } catch {
      return '0.0.0';
    }
  })());

  return {
    dir: {
      input:    '.',
      includes: '_includes',
      output:   '_site',
    },
    markdownTemplateEngine: 'njk',
    templateFormats: ['md', 'njk'],
    ignoredFiles: ['.conform.*'],
  };
};
