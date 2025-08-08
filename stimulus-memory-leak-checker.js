#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Simple script to check for event listener leaks in Stimulus controllers
function checkFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const errors = [];

  // Check if this is a Stimulus controller
  if (!content.includes('extends Controller') && !content.includes('export default class extends Controller')) {
    return errors;
  }

  const hasEventListeners = content.includes('addEventListener');
  const hasDocumentListeners = content.includes('document.addEventListener');
  const hasDisconnectMethod = content.includes('disconnect()');
  const hasBoundReferences = content.match(/this\.bound\w+\s*=/);
  const hasInlineListeners = content.match(/addEventListener\([^,]+,\s*(?:\([^)]*\)\s*=&gt;|function\s*\()/);

  if (hasEventListeners && !hasDisconnectMethod) {
    errors.push({
      file: filePath,
      line: getLineNumber(content, 'addEventListener'),
      message: 'Stimulus controller adds event listeners but is missing disconnect() method for cleanup'
    });
  }

  if (hasDocumentListeners && hasDisconnectMethod) {
    // Check if document listeners are cleaned up in disconnect
    const disconnectContent = extractMethodContent(content, 'disconnect');
    if (disconnectContent && !disconnectContent.includes('removeEventListener')) {
      errors.push({
        file: filePath,
        line: getLineNumber(content, 'document.addEventListener'),
        message: 'Document event listener added without proper cleanup in disconnect() method'
      });
    }
  }

  if (hasInlineListeners && !hasBoundReferences) {
    errors.push({
      file: filePath,
      line: getLineNumber(content, 'addEventListener'),
      message: 'Event listener added without storing bound reference for cleanup in disconnect()'
    });
  }

  return errors;
}

function getLineNumber(content, searchText) {
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes(searchText)) {
      return i + 1;
    }
  }
  return 1;
}

function extractMethodContent(content, methodName) {
  const methodRegex = new RegExp(`${methodName}\\s*\\([^)]*\\)\\s*\\{([^}]*)\\}`, 's');
  const match = content.match(methodRegex);
  return match ? match[1] : null;
}

function walkDirectory(dir) {
  const files = fs.readdirSync(dir);
  let allErrors = [];

  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      allErrors = allErrors.concat(walkDirectory(filePath));
    } else if (file.endsWith('.js') && file.includes('controller')) {
      const errors = checkFile(filePath);
      allErrors = allErrors.concat(errors);
    }
  }

  return allErrors;
}

function main() {
  const jsDir = path.join(process.cwd(), 'app', 'javascript');

  if (!fs.existsSync(jsDir)) {
    console.log('No app/javascript directory found');
    return;
  }

  const errors = walkDirectory(jsDir);

  if (errors.length === 0) {
    console.log('✓ No event listener memory leaks detected in Stimulus controllers');
    process.exit(0);
  } else {
    console.log('✗ Event listener memory leaks detected:');
    console.log();

    errors.forEach(error => {
      console.log(`${error.file}:${error.line}`);
      console.log(`  ${error.message}`);
      console.log();
    });

    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
