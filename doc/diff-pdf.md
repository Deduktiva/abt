# PDF Visual Comparison Setup

## Tool: diff-pdf

The package is either `diff-pdf` or `diff-pdf-wx`, and it can be used by calling `diff-pdf`.

### Usage for Visual PDF Comparison

```bash
# Compare two PDFs and output differences to a new PDF file
diff-pdf --output-diff=differences.pdf --mark-differences --grayscale file1.pdf file2.pdf

# Options used:
# --output-diff: Save visual differences to a PDF file
# --mark-differences: Mark differences on the left side  
# --grayscale: Show unchanged parts as gray, differences in color
# --skip-identical: Only output pages with differences (optional)
# --dpi=300: High resolution for detailed comparison (default)
```

### For Invoice PDF Testing

1. Generate baseline PDF with original template
2. Generate comparison PDF with refactored template  
3. Use diff-pdf to create visual comparison:
   ```bash
   diff-pdf --output-diff=invoice_comparison.pdf --mark-differences --grayscale baseline_invoice.pdf refactored_invoice.pdf
   ```
4. If no output file is generated, the PDFs are identical
5. If differences exist, examine the output PDF to see highlighted changes

### Environment Note
- Requires X11/GUI for `--view` option
- Can run headless for file output without display
