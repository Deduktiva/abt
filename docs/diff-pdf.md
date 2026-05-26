# Visual PDF comparison with `diff-pdf`

Tool: the `diff-pdf` (or `diff-pdf-wx`) Debian package — both ship the `diff-pdf` binary. Runs headless when used with `--output-diff` (no display required).

```bash
diff-pdf --output-diff=differences.pdf --mark-differences --grayscale a.pdf b.pdf
```

- No output file written → PDFs are identical.
- Output file written → open it to see highlighted differences (unchanged content gray, differences in color).

Typical use: regenerate an invoice/delivery-note PDF after touching `lib/foptemplate/*.xsl` and diff it against a baseline kept aside.
