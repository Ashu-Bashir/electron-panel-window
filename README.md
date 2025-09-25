# electron-panel-window

This is an updated fork of [@akiflow/electron-panel-window](https://github.com/akiflow/electron-panel-window) with extended compatibility support.

**Compatibility:**
- ✅ **macOS Sequoia & Tahoe (26.x)** - Tested and working
- ✅ **macOS Ventura** - Previously tested
- ✅ **Electron 36.x** - Tested and working  
- ✅ **Electron 21.x** - Previously supported

This package has been updated to support much higher versions of Electron than the original Akiflow package, which was limited to Electron 21.x. The current version extends compatibility significantly and has been tested with modern Electron releases.

**There are few caveats.**

### 1. `titleBarStyle` should have the value `'customButtonsOnHover'`
This will show two buttons on top left (to close and maximize the window). You can hide them by setting:
* `closable: false`
* `maximizable: false`

Beware that you may need some additional logic if you actually need to close the window, as `win.close()` won't work at this point. (you can check the test to see how we did this)

This looks no longer necessary in version 3.

### 2. `setVisibleOnAllWorkspaces(true)` cannot be used on these windows
Apparently it causes everything to crash.

### 3. Crash on quit
There are usually some electron crash when quitting an app with a panel window.
Usually they can be fixed by:
1. hiding the panel window
2. make another window as key (use `makeKeyWindow` on another window)
3. transform the panel in a normal window (use `makeWindow`)
4. close the window
5. quit the app

We have noticed less/no crashes if steps 2-5 are execture after a setTimout like:
```
win.hide()
setTimeout(()=>{
    electronPanelWindow.makeKeyWindow(otherWin)
    electronPanelWindow.makeWindow(win)
    win.close()
    app.quit()
})
```

## Improvements in This Fork

- **Extended Electron Support**: Updated to work with Electron versions beyond 21.x, tested up to 36.x
- **Modern macOS Compatibility**: Verified compatibility with macOS Tahoe (26.x) 
- **Maintained Stability**: Preserves all existing functionality while expanding version support

## Other
Removed Windows and Linux support as it was empty in the original implementation.

You may want to include the package dynamically:
```javascript
const electronPanelWindow = process.platform === 'darwin' ? require('electron-panel-window') : undefined
```

### Issues
Feel free to open an issue, and report other "workarounds" to keep this working.

# Methods
Install

```bash
npm install @ashubashir/electron-panel-window
```

require

```bash
const electronPanelWindow = process.platform === 'darwin' ? require('@ashubashir/electron-panel-window') : undefined
```

1. `makeKeyWindow(win)` focus the window without activating the application
2. `makePanel(win)` transform the given window in a panel
3. `makeWindow(win)` transform the given panel in a window (useful before quitting)

# Credits
* [AshuBashir] 
* [Manirathnam]

---

### Old README of electron-panel-window
Something may be useful, something may be outdated

You can find it here: [https://www.npmjs.com/package/@akiflow/electron-panel-window?activeTab=readme]
