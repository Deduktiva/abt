# Code Coverage

This project uses [SimpleCov](https://github.com/simplecov-ruby/simplecov) for code coverage reporting.

## Current Coverage

- **Target:** 60% minimum line coverage
- **Branch Coverage:** Enabled for more thorough testing
- **Current Status:** Run `bundle exec rails test` to see latest coverage

## Local Development

### Running Tests with Coverage

```bash
bundle exec rails test
```

Coverage reports are automatically generated when running tests in the `test` environment.

### Viewing Coverage Reports

After running tests, open the HTML coverage report:

```bash
open coverage/index.html
```

The report shows:
- Line-by-line coverage with color coding
- File-by-file coverage percentages
- Coverage by application component (Controllers, Models, etc.)

## CI Integration

Coverage is automatically measured in GitHub Actions:

- **HTML Reports:** Available as CI artifacts for 30 days
- **LCOV Format:** Generated for potential integration with external services
- **Thresholds:** CI fails if coverage drops below 60% or decreases by more than 5%

## Configuration

Coverage configuration is in `test/test_helper.rb`:

- **Filtered Directories:** `/config/`, `/db/`, `/test/`, `/vendor/`
- **Grouped by:** Controllers, Models, Helpers, Services, Jobs, Mailers
- **Branch Coverage:** Enabled for comprehensive testing
- **Minimum Coverage:** 60% (can be increased as coverage improves)

## Improving Coverage

1. **Identify gaps:** Review HTML report for uncovered lines
2. **Focus on critical paths:** Prioritize controllers and models
3. **Add meaningful tests:** Avoid coverage-only tests
4. **Regular monitoring:** Check coverage trends in CI

## Coverage Goals

- **Short-term:** Maintain 60%+ coverage
- **Long-term:** Increase to 80%+ as test suite grows
- **Critical components:** Aim for 90%+ coverage on invoice/payment logic