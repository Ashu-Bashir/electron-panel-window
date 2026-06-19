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
  return v8::External::New(v8::Isolate::GetCurrent(), value,
                          v8::kExternalPointerTypeTagDefault);
}`
  }
]);

// Patch nan_callbacks_12_inl.h - replace .Value() calls
const callbacksPath = path.join(nanDir, 'nan_callbacks_12_inl.h');
try {
  let content = fs.readFileSync(callbacksPath, 'utf8');
  const original = content;
  
  content = content.replace(
    /\.As<v8::External>\(\)->Value\(\)/g,
    '.As<v8::External>()->Value(v8::kExternalPointerTypeTagDefault)'
  );
  
  if (content !== original) {
    fs.writeFileSync(callbacksPath, content, 'utf8');
    console.log(`✓ Patched nan_callbacks_12_inl.h`);
  }
} catch (err) {
  console.error(`✗ Failed to patch nan_callbacks_12_inl.h:`, err.message);
}

console.log('NaN patching complete!');
