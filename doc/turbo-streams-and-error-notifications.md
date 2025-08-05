# Turbo Streams and Error Notifications

This document describes the Turbo Streams implementation and error notification system added to the ABT application.

## Overview

Two major features were implemented:
1. **Turbo Streams support** for modern AJAX-style interactions
2. **Error notification system** with navbar integration for handling network/server errors

## Turbo Streams Implementation

### Configuration

Turbo Streams are configured in `app/javascript/application.js`:

```javascript
// Enable Turbo Streams
import { Turbo } from "@hotwired/turbo-rails"
Turbo.config.drive.progressBarDelay = 100
```

### Usage Example

The `projects_controller.rb` demonstrates Turbo Stream usage:

```ruby
respond_to do |format|
  if @project.save
    format.html { redirect_to @project, notice: 'Project was successfully created.' }
    format.turbo_stream { render turbo_stream: turbo_stream.prepend("projects", partial: "projects/project", locals: { project: @project }) }
    format.json { render json: @project, status: :created, location: @project }
  else
    format.html { render :new, status: :unprocessable_content }
    format.turbo_stream { render turbo_stream: turbo_stream.replace("project_form", partial: "projects/form", locals: { project: @project }) }
    format.json { render json: @project.errors, status: :unprocessable_content }
  end
end
```

### Future Implementation

To add Turbo Stream support to other controllers:
1. Add `format.turbo_stream` responses to create/update/destroy actions
2. Use `turbo_stream.prepend`, `turbo_stream.replace`, `turbo_stream.remove`, etc.
3. Ensure forms and links use `data-turbo-method` and proper targeting

**Note**: Any future AJAX interactions (whether using Turbo Streams, fetch API, or other JavaScript HTTP requests) should integrate with the error notification system. Network/server errors from these interactions should be reported by calling the error notification controller's `addError()` method to maintain consistent user experience.

## Error Notification System

### Architecture

The error notification system consists of:

- **Stimulus Controller**: `app/javascript/controllers/error_notification_controller.js`
- **Navbar Integration**: `app/views/layouts/_navigation.html.haml`
- **Automatic Error Detection**: Network errors, server errors, form failures

### Features

1. **Red Badge**: Shows error count in navbar (only when errors exist)
2. **Dropdown List**: Click badge to see recent errors with timestamps
3. **Auto-Detection**: Listens for various Turbo and network events
4. **Manual Clearing**: Individual × buttons or "Clear All" functionality
5. **Offline Detection**: Handles network offline/online events

### Error Types Detected

- **Network failures**: `turbo:fetch-request-error` events
- **Server errors**: `turbo:frame-missing` events
- **Form failures**: `turbo:submit-end` with unsuccessful responses
- **Offline/Online**: Browser network state changes

### Testing

For manual testing, use browser console:

```javascript
// Find and trigger test error
const errorController = window.Stimulus.controllers.find(c => c.identifier === 'error-notification');
errorController.testError({ params: { message: "Test error message" }});
```

### UI Behavior

- **No errors**: Nothing visible in navbar
- **With errors**: Red badge with count appears next to Configuration dropdown
- **Click badge**: Opens dropdown showing recent errors (max 5)
- **Click outside**: Closes dropdown
- **Click "Clear All"**: Removes all errors but keeps dropdown open
- **Click ×**: Removes individual error

### Implementation Details

#### Event Handling
- All events use `preventDefault()` and `stopPropagation()` to prevent conflicts
- Outside clicks close the dropdown via document event listener
- Dropdown content clicks are prevented from bubbling up

#### Limitations
- Limits to 5 most recent errors
- Auto-cleanup when coming back online

### Troubleshooting

#### Controller Not Found
If `el.controller` returns undefined, access via:
```javascript
const errorController = window.Stimulus.controllers.find(c => c.identifier === 'error-navigation');
```
