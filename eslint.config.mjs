import globals from "globals"
import stimulusEventListenerCleanup from "./eslint/rules/stimulus-event-listener-cleanup.mjs"

export default [
  {
    ignores: ["node_modules/", "vendor/", "public/"],
  },
  {
    files: ["app/javascript/**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: { ...globals.browser },
    },
    plugins: {
      "stimulus-local": {
        rules: {
          "event-listener-cleanup": stimulusEventListenerCleanup,
        },
      },
    },
    rules: {
      "no-restricted-syntax": [
        "error",
        {
          selector: "ImportDeclaration[source.value=/^\\.\\.?\\//]",
          message:
            'Use importmap paths like "controllers/foo_controller" instead of relative imports — relative paths break under the production importmap.',
        },
      ],
      "stimulus-local/event-listener-cleanup": "error",
    },
  },
]
