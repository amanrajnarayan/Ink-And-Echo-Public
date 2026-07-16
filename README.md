# 🌿 Ink & Echo

A minimalist, parchment-inspired digital journal designed for quiet reflection. **Ink & Echo** bridges the gap between the tactile feel of a physical notebook and the permanence of digital storage.

---

## ✨ Features

* **Dual-Canvas Typography (Parchment & Dark Vellum):** Eye-strain-reducing palettes designed for any time of day. Switch instantly between a bright midday Cream (`#FDF6E3`) and a rich, late-night Midnight Charcoal (`#1E1E1E`) with soft amber accents.
* **Inline CRUD Cycles:** Seamless entry creation, instant modifications via an integrated edit-state loop, and secure deletion mechanisms without leaving the primary feed.
* **Dynamic Mood Filters:** Categorize and filter historical entries in real-time using an indexed memory-sorting engine mapped to expressive metadata (🌿, ✨, ☕️, 🎧, ✈️, etc.).
* **Paper Styles:** Choose your custom canvas for exports—Plain, Ruled (Legal), Dotted (BuJo), or Squared (Grid).
* **Tactile Haptics:** Deeply integrated haptic engine tuned for physical, high-fidelity feedback on selections, saves, deletions, and state toggles.
* **Implicit Intent Sharing:** Direct "Share to IG Stories" integration, converting custom-rendered canvases into sleek, shareable system payloads.
* **Time Machine (Data Management):** Native file-system backup and restore functionality to ensure memories are safely migrated across devices.
* **Privacy First:** Local-only storage using Hive. No cloud sync, no tracking, complete digital privacy.

---

## 🛠 Tech Stack

* **Framework:** Flutter (3.x)
* **Database:** Hive (NoSQL local persistence)
* **Typography:** Merriweather, Oswald, and Cedarville Cursive (for signatures).
* **Implicit Intents:** `share_plus` for system-level sharing hooks.
* **File System:** `path_provider` & `file_picker` for secure database migration.

---

## 📸 Technical Highlights

### Dynamic State Editing & Deduplication
To maintain a minimalist footprint, the app avoids separate entry screens. It utilizes an asynchronous state index pointer (`_editingKey`). When active, the main writing interface shifts its decoration box layout, pre-populates state controllers, and updates the targeted Hive key via an upsert pattern (`box.put`), mathematically preventing double-entry duplicates.

### Real-Time Memory Indexing Engine
The list history architecture bypasses standard linear iteration by building isolated runtime filter structures (`filteredKeys` and `filteredEntries`) inside the build frame. This filters text contents and mood payloads instantly without triggering wasteful database reads.

### Responsive Custom Painters
The custom drawing layers (`PaperPainter`) adapt automatically to active theme variables. When **Midnight Mode** is toggled, gridlines and dots are re-rendered to low-contrast shades (`#2D2D2D`), ensuring the background architecture never conflicts with the legibility of the amber ink strings.

### Secure File-System Migration
To handle modern "Scoped Storage" boundaries, the **Time Machine** architecture reads raw bytes from the sandbox data directory, piping the underlying `.hive` binary via a stream directly to an OS system wrapper hook (`FilePicker.saveFile`), completely bypassing broad internal file storage permissions.

### Optimized Haptic Mapping

| Action / State | Haptic Trigger | Sensation Profile |
| :--- | :--- | :--- |
| **Mood Selector / Theme Toggle** | `selectionClick` | Crisp, crisp mechanical switch tick |
| **Commit Save / Update** | `lightImpact` | Subtle, soft confirmation tap |
| **Edit Hook Trigger** | `mediumImpact` | Distinct, responsive tactile feedback |
| **Backup / Data Overwrite** | `vibrate` | Deep, secure systemic pulse |
| **Delete Lifecycle (Hold)** | `heavyImpact` | Urgent warning alert drop |
---

## 🚀 Installation & Build

1.  **Clone the repo:**
    ```bash
    git clone [https://github.com/amanrajnarayan/Ink-Echo.git](https://github.com/amanrajnarayan/Ink-Echo-Public.git)
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Build for Android (Optimized):**
    ```bash
    flutter build apk --release --target-platform android-arm64
    ```
    *Target the `app-arm64-v8a-release.apk` for modern devices.*

---

## 📜 License
Private Project - © 2026 Aman Raj.