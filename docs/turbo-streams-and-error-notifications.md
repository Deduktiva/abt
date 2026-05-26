# Turbo Streams and Error Notifications

## Turbo Streams

Enabled in `app/javascript/application.js` via `@hotwired/turbo-rails`. No controllers currently emit `format.turbo_stream` for CRUD; the only live use is `ProjectsController#index` rendering a partial for XHR filter updates.

If you add a new AJAX path (Turbo Stream, fetch, anything), surface failures through the error notification system below — don't swallow them.

## Error notifications

A navbar badge that aggregates client-side request failures.

- Stimulus controller: `app/javascript/controllers/error_notification_controller.js`
- Navbar mount: `app/views/layouts/_navigation.html.haml`

Listens on `document` / `window` for `turbo:fetch-request-error`, `turbo:frame-missing`, `turbo:submit-end` (unsuccessful response), and `offline` / `online`. Keeps the 5 most recent entries, drops "you are offline" entries when the browser comes back online. The badge is hidden until at least one error is present.

To push a custom error from other code, call `addError({ id, message, timestamp, type })` on the controller instance.

### Manual test

```javascript
window.Stimulus.controllers
  .find(c => c.identifier === 'error-notification')
  .testError({ params: { message: 'Test error' } })
```
