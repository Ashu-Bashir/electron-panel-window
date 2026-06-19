#!/usr/bin/env node
/**
 * Patch NaN for V8 12.9+ (Electron 42+) compatibility
 * Adds ExternalPointerTypeTag parameters required by new V8 API
 * Handles both direct dependencies and hoisted node_modules
 */

const fs = require('fs');
const path = require('path');

// Find NaN directory - check multiple possible locations
function findNaNDir() {
  const locations = [
    path.join(__dirname, '../node_modules/nan'),  // Direct dependency
    path.join(__dirname, '../../nan'),             // Hoisted sibling
    path.join(__dirname, '../../../nan'),          // Further hoisted
  ];
  
  for (const loc of locations) {
    if (fs.existsSync(loc) && fs.existsSync(path.join(loc, 'nan.h'))) {
      console.log(`✓ Found NaN at: ${loc}`);
      return loc;
    }
  }
  
  throw new Error('Could not find NaN module in any expected location');
}

const nanDir = findNaNDir();

function patchFile(filePath, replacements) {
  try {
    if (!fs.existsSync(filePath)) {
      console.error(`✗ File not found: ${filePath}`);
      return;
    }
    
    let content = fs.readFileSync(filePath, 'utf8');
    let patched = false;

    replacements.forEach(({ search, replace }) => {
      if (content.includes(search)) {
        content = content.replace(search, replace);
        patched = true;
      }
    });

    if (patched) {
      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`✓ Patched ${path.basename(filePath)}`);
    }
  } catch (err) {
    console.error(`✗ Failed to patch ${filePath}:`, err.message);
  }
}

// Patch nan_implementation_12_inl.h
patchFile(path.join(nanDir, 'nan_implementation_12_inl.h'), [
  {
    search: `Factory<v8::External>::return_t
Factory<v8::External>::New(void * value) {
  return v8::External::New(v8::Isolate::GetCurrent(), value);
}`,
    replace: `Factory<v8::External>::return_t
Factory<v8::External>::New(void * value) {
  return v8::External::New(v8::Isolate::GetCurrent(), value, 0);
}`
  }
]);

// Patch all External::New callback calls with regex
const implPath = path.join(nanDir, 'nan_implementation_12_inl.h');
try {
  if (fs.existsSync(implPath)) {
    let content = fs.readFileSync(implPath, 'utf8');
    const original = content;
    
    // Match all External::New calls with callback parameter and add the tag
    content = content.replace(
      /v8::External::New\(isolate, reinterpret_cast<void \*>\(callback\)\)\);/g,
      'v8::External::New(isolate, reinterpret_cast<void *>(callback), 0));'
    );
    
    if (content !== original) {
      fs.writeFileSync(implPath, content, 'utf8');
      console.log(`✓ Patched External::New callback calls in nan_implementation_12_inl.h`);
    }
  }
} catch (err) {
  console.error(`✗ Failed to patch External::New callbacks:`, err.message);
}

// Patch nan_callbacks_12_inl.h - replace ALL Value() calls including nested ones
const callbacksPath = path.join(nanDir, 'nan_callbacks_12_inl.h');
try {
  if (fs.existsSync(callbacksPath)) {
    let content = fs.readFileSync(callbacksPath, 'utf8');
    const original = content;
    
    // Replace all Value() calls that don't already have a parameter with Value(0)
    // This handles both .As<v8::External>()->Value() and nested chains
    content = content.replace(
      /->Value\(\)/g,
      '->Value(0)'
    );
    
    if (content !== original) {
      fs.writeFileSync(callbacksPath, content, 'utf8');
      console.log(`✓ Patched Value() calls in nan_callbacks_12_inl.h`);
    }
  }
} catch (err) {
  console.error(`✗ Failed to patch Value() calls:`, err.message);
}

console.log('NaN patching complete!');

