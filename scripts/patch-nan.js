#!/usr/bin/env node
/**
 * Patch NaN for V8 12.9+ (Electron 42+) compatibility
 * Adds ExternalPointerTypeTag parameters required by new V8 API
 */

const fs = require('fs');
const path = require('path');

const nanDir = path.join(__dirname, '../node_modules/nan');

function patchFile(filePath, replacements) {
  try {
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
  let content = fs.readFileSync(implPath, 'utf8');
  const original = content;
  
  // Match all External::New calls with callback parameter and add the tag (use 0 instead of kExternalPointerTypeTagDefault)
  content = content.replace(
    /v8::External::New\(isolate, reinterpret_cast<void \*>\(callback\)\)\);/g,
    'v8::External::New(isolate, reinterpret_cast<void *>(callback), 0));'
  );
  
  if (content !== original) {
    fs.writeFileSync(implPath, content, 'utf8');
    console.log(`✓ Patched External::New callback calls in nan_implementation_12_inl.h`);
  }
} catch (err) {
  console.error(`✗ Failed to patch External::New callbacks:`, err.message);
}

// Patch nan_callbacks_12_inl.h - replace all Value() calls with tag parameter
const callbacksPath = path.join(nanDir, 'nan_callbacks_12_inl.h');
try {
  let content = fs.readFileSync(callbacksPath, 'utf8');
  const original = content;
  
  // Replace all .Value() calls with .Value(0) 
  content = content.replace(
    /\.As<v8::External>\(\)->Value\(\)/g,
    '.As<v8::External>()->Value(0)'
  );
  
  if (content !== original) {
    fs.writeFileSync(callbacksPath, content, 'utf8');
    console.log(`✓ Patched Value() calls in nan_callbacks_12_inl.h`);
  }
} catch (err) {
  console.error(`✗ Failed to patch Value() calls:`, err.message);
}

console.log('NaN patching complete!');
