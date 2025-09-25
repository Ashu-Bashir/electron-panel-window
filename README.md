# electron-panel-window

An enhanced version of [@akiflow/electron-panel-window](https://github.com/akiflow/electron-panel-window) by **@ashubashir**, building upon the solid foundation created by Akiflow. While the original package stopped supporting after Electron 21.x, this fork extends compatibility to modern Electron versions (>21x) with active maintenance and new improvements. Currently, tested upto Electron version 36x.

**Compatibility:**
- ✅ **macOS Ventura** - Previously tested
- ✅ **Electron 21.x** - Previously supported
- ✅ **macOS Tahoe (26.x)** - Tested and working
- ✅ **Electron 36.x** - Tested and working  

## What are Panel Windows?

Panel windows are special macOS windows that behave differently from regular application windows. They can appear above other windows without stealing focus from the active application, making them perfect for:

- **Floating toolbars** and utility panels
- **Always-on-top widgets** that don't interfere with workflow  
- **Quick access menus** and popover-style interfaces
- **Dashboard overlays** that complement the main application

This package provides simple methods to transform regular Electron windows into native macOS panel windows, giving your app a more integrated and professional feel on Mac.

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
* [AshuBashir] <https://github.com/ashu-Bashir> 
* [Manirathnam] <https://github.com/manipandi>
