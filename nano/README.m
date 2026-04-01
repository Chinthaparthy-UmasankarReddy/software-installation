The `nano` editor is a favorite for quick terminal edits because it’s straightforward, but its keyboard shortcuts can feel a bit "retro" if you’re used to modern GUIs. 

In `nano`, the **^** symbol represents the **Ctrl** key, and **M-** represents the **Meta** key (usually **Alt** on Windows/Linux or **Esc** on Mac).

### Essential Shortcut Keys

| Action | Shortcut |
| :--- | :--- |
| **Save (Write Out)** | `Ctrl + O` |
| **Exit** | `Ctrl + X` |
| **Search (Where Is)** | `Ctrl + W` |
| **Paste (Uncut)** | `Ctrl + U` |
| **Go to Line Number** | `Ctrl + _` (Ctrl + Shift + Hyphen) |
| **Undo** | `Alt + U` |
| **Redo** | `Alt + E` |

---

### How to Delete Multiple Lines

There isn't a single "delete" key for blocks of text in `nano`, so you have to use the **"Cut"** mechanism. Here are the two best ways to do it:

#### Method 1: The "Rapid Cut" (Line by Line)
If you only have a few lines to delete, you can simply "kill" them one by one.
1. Move your cursor to the first line you want to delete.
2. Press `Ctrl + K` repeatedly. Each press deletes the entire current line.
3. **Note:** These lines are stored in a buffer. If you accidentally delete too many, press `Ctrl + U` to paste them back.

#### Method 2: The "Mark and Kill" (For Large Blocks)
This is the closest thing to "highlight and delete" in `nano`.
1. Move your cursor to the **start** of the text block you want to delete.
2. Press `Alt + A` (or `Ctrl + ^`) to set a **Mark**. You will see `[ Mark Set ]` appear at the bottom.
3. Use the arrow keys to highlight the text you want to remove.
4. Press `Ctrl + K` to "cut" (delete) the entire highlighted block.

---

### Pro Tip: Deleting without "Cutting"
If you want to delete text without overwriting what is currently in your "paste" buffer (the stuff you last cut), you can use the **Select** method above but hit **Backspace** or **Delete** instead of `Ctrl + K`. However, in some older versions of `nano`, this might only delete a single character, so `Ctrl + K` remains the most reliable way to clear out space.
