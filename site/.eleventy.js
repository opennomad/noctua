module.exports = function (eleventyConfig) {
  // Copy static assets through unchanged.
  eleventyConfig.addPassthroughCopy('img');
  eleventyConfig.addPassthroughCopy({ '../assets/logo.svg': 'assets/logo.svg' });

  return {
    dir: {
      input:    '.',
      includes: '_includes',
      output:   '_site',
    },
    markdownTemplateEngine: false,
  };
};
