const fs = require('fs');
const path = require('path');

module.exports = function (eleventyConfig) {
  // Copy static assets through unchanged.
  eleventyConfig.addPassthroughCopy('img');
  eleventyConfig.addPassthroughCopy({ '../assets/logo.svg': 'assets/logo.svg' });

  // Global data: version from pubspec.yaml (strips +buildnum).
  eleventyConfig.addGlobalData('version', (() => {
    try {
      const pubspec = fs.readFileSync(path.join(__dirname, '..', 'pubspec.yaml'), 'utf8');
      const match = pubspec.match(/^version:\s*(\S+)/m);
      return match ? match[1].split('+')[0] : '0.0.0';
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
