# Copper — 1 FPS Video Audit Addendum

**Based on:** `/mnt/data/copper.mp4`  
**Method:** extracted **1 frame per second** across the full video  
**Result:** **47 frames**, not 43, because the video duration is approximately **47.25 seconds**.

This addendum reviews the full 1 FPS sweep and checks whether anything material is missing from `copper_product_analysis_final.md`.

---

## 1. Quick Conclusion

The existing final Markdown is **already very strong and mostly complete** for a reverse-engineering handoff.

After reviewing all 47 frames, I would say:

- **No major product capability is missing** from the final Markdown.
- A few **minor behavioural / presentation details** can be added or clarified.
- The biggest value of the 1 FPS audit is not discovering brand-new features, but **increasing confidence** that the current reconstruction is accurate.

---

## 2. What the 1 FPS Audit Confirms

### 2.1 Marketing / scope claims confirmed visually

The video explicitly claims:

- **It works everywhere**
- **ChatGPT. Claude. Cursor. Chrome. Apps. Chats. Tabs. Everywhere.**
- **Send them to your chat with one shortcut...**
- Feature summary:
  - Merge Notes
  - Sections
  - Markdown
  - Copy as List
  - Search
  - Custom Shortcuts
  - Local Files
  - No Tracking
  - No Account
  - Free Updates
  - Keyboard-First
  - Native Mac App

These claims are already mostly represented in the final Markdown, but the “works everywhere / apps, chats, tabs” phrasing can be called out more explicitly.

### 2.2 Interaction flow confirmed end-to-end

The 47-frame sweep clearly validates the full loop:

1. User is working in a chat app.
2. Copper sits as a compact companion window on the right.
3. User selects text in the source app.
4. User presses **Shift + Shift**.
5. A **Captured** toast appears over the source app.
6. The selected snippet appears in Copper.
7. User later writes additional prompts manually in Copper.
8. User multi-selects two queued prompts.
9. User opens a context menu.
10. User chooses **Copy as List**.
11. Both prompts become completed.
12. A **Copied as List** toast appears.
13. The numbered list is pasted back into the chat input.

That flow is fully consistent with the main reverse-engineering file.

---

## 3. Minor Additions Worth Making to the Main Markdown

These are the small details I would add.

### 3.1 Explicitly document the “works everywhere” positioning

**Suggested addition:**

> The video repeatedly positions Copper as a cross-app companion rather than an AI-chat-only utility. The wording “ChatGPT. Claude. Cursor. Chrome. Apps. Chats. Tabs. Everywhere.” suggests the intended surface area is any app where text can be selected and later reused.

**Why add it:**
The final Markdown mentions ChatGPT / Claude / Cursor / Chrome, but this broader “apps, chats, tabs, everywhere” framing is part of the product positioning.

---

### 3.2 Add a note about the initial visual state seen in the video

**Suggested addition:**

> In the earliest product shot, Copper is already rendered as a populated panel with a visible search field, section headers and bottom composer, even before the main capture sequence starts. This confirms the panel's baseline chrome and reinforces that search + composer are persistent structural elements of the layout.

**Why add it:**
This is not a new feature, but it is useful for clone accuracy.

---

### 3.3 Add a note that the Copper panel shows no visible traffic-light window controls

**Suggested addition:**

> In all shown states, Copper does not display the standard macOS red/yellow/green traffic-light buttons, which reinforces its utility-panel feel.

**Why add it:**
This is already mentioned once in the existing final Markdown, but it is important enough for UI fidelity that it could also be repeated in the reconstruction checklist.

---

### 3.4 Add that the list paste preserves top-to-bottom card order

**Suggested addition:**

> In the demonstrated `Copy as List` flow, the pasted numbered list preserves the same top-to-bottom order as the two selected cards in Copper.

**Why add it:**
This is useful implementation guidance for a faithful clone.

---

### 3.5 Add a note about the absence of destructive actions in the visible context menu

**Suggested addition:**

> The demonstrated context menu does not expose delete, archive or trash actions. This does not prove they do not exist elsewhere, but they are not part of the visible primary note actions shown in the video.

**Why add it:**
This helps avoid overbuilding the first clone version.

---

## 4. Things the 1 FPS Audit Does *Not* Prove

Even with 47 extracted frames, the following remain unknown:

- exact resizing behaviour;
- whether the panel is draggable, pinnable or always-on-top;
- whether the panel scrolls with inertia or virtualisation;
- exact rules for assigning a new capture to a section;
- exact section creation / rename UI;
- exact selection gesture (`cmd+click`, `shift+click`, etc.);
- exact persistence file format and file path;
- whether `Copy` on multiple notes differs from `Copy as List`;
- whether completion is always automatic after `Copy as List`, or just in the demonstrated flow;
- whether any settings UI exists behind the top-right ellipsis and what it contains.

So the extra frames improve confidence, but they do **not** remove the need for hands-on testing if you later buy the app and want pixel- and behaviour-level parity.

---

## 5. Recommended Delta to the Main File

### Overall verdict

`copper_product_analysis_final.md` should remain the **main document**.

I would only apply a **light revision**, not a rewrite.

### Revision summary

Add or strengthen:

1. **Cross-app positioning** — “Apps. Chats. Tabs. Everywhere.”
2. **Persistent shell layout** — search, sections and composer are always visible in the video.
3. **Top-to-bottom order preservation** for `Copy as List` output.
4. **No visible destructive action** in the shown context menu.
5. Optionally note that the 1 FPS audit covered the full **47 seconds / 47 frames**.

---

## 6. Reverse-Engineering Takeaway for Your Personal Clone

For a personal-use clone, the current product spec is already good enough to implement a very close reproduction if you build around these pillars:

- compact floating right-side utility panel;
- local-first notes file;
- sectioned note list;
- Markdown note rendering;
- capture selected text via Accessibility + global shortcut;
- manual prompt composer at the bottom;
- multi-select notes;
- context menu actions;
- `Copy as List` => numbered clipboard output + mark done;
- keyboard-first interaction;
- privacy-first / no account.

If you want a practical engineering order, I would implement in this sequence:

1. window shell + styling;
2. local persistence;
3. note cards + sections + composer;
4. search;
5. global capture with `Shift + Shift`;
6. selection model;
7. context menu;
8. `Copy as List` flow;
9. toasts;
10. settings / custom shortcuts.

---

## 7. Generated Artifacts

- Full extracted frames folder: `/mnt/data/copper_fps1_frames/`
- Contact sheet: `/mnt/data/copper_fps1_contact_sheet.jpg`
- OCR sweep (rough): `/mnt/data/copper_fps1_ocr.tsv`
- ZIP bundle of the 1 FPS extraction: `/mnt/data/copper_fps1_frames.zip`

