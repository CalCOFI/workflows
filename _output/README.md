# workflows

scripts to explore and load data into the CalCOFI database

## notebooks

These web pages (\*.html) are typically rendered from Quarto or R markdown (\*.qmd, \*.Rmd) source files:

<!-- Jekyll rendering -->
{% for file in site.static_files %}
  {% if file.extname == '.html' %}
* [{{ file.basename }}]({{ site.baseurl }}{{ file.path }})
  {% endif %}
{% endfor %}

## source

These notebook web pages (\*.html) are typically rendered from Rmarkdown (\*.Rmd) or Quarto markdown (\*.qmd) source files:

- [github.com/CalCOFI/workflows](https://github.com/CalCOFI/workflows)

