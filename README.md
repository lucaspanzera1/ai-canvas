<div align="center">
  <img src="./.github/src/cat.png" width="150" alt="AI Canvas Logo">
   <h1>AI Canvas </h1>
</div>

[![Português](https://img.shields.io/badge/Leia_em-Português-green.svg)](README-pt.md)

---

## 💡 About the Project
**AI Canvas** is an open-source digital notebook ecosystem built specifically for the **iPad**, bridging the gap between the natural Apple Pencil handwriting experience and the power of Artificial Intelligence.

The core idea is to provide a minimalist, distraction-free environment where you can organize multiple notebooks, write using Apple's native ink aesthetics on infinite A4-segmented canvases, and leverage multiple Multimodal AI providers to enhance your learning process and problem-solving. This tool acts as your intelligent study companion, capable of understanding both your handwritten notes and complex diagrams.

## ✨ Key Features
* **Native Apple Aesthetics:** Low-latency, highly optimized handwriting experience using PencilKit for iPad and Apple Pencil.
* **Infinite Workspace:** An infinite, scrollable canvas segmented into A4 pages, complete with customizable line and grid backgrounds.
* **PDF Export:** Export your infinite canvas to PDF effortlessly, perfectly capturing your handwriting alongside chosen background patterns (lines/grids) for seamless sharing.
* **Dark Mode Support:** Fully optimized for both light and dark modes, ensuring a comfortable note-taking experience in any environment.
* **Smart Notebook Management:** Manage multiple notebooks for different subjects with a delightful, gamified grid interface and auto-saving.
* **Multimodal AI Integration:** A built-in AI chat panel that can "see" your canvas and help you:
    * Perform complex mathematical and engineering calculations based on your hand-drawn formulas.
    * Summarize handwritten or typed notes.
    * Explain difficult concepts and provide additional context directly from your sketches.
* **Bring Your Own AI:** Securely add your own API keys via Keychain for multiple leading AI providers, featuring a highly-polished API key management experience. Integrated providers include:
    * **Google Gemini** (Vision capabilities)
    * **OpenAI (ChatGPT)** (Vision capabilities)
    * **Anthropic Claude** (Vision capabilities)
    * **Groq** (Fast text inference)

## 🛠 Tech Stack
* **Frontend:** Swift, SwiftUI, PencilKit
* **AI Engine/Providers:** Gemini, OpenAI, Claude, Groq APIs
* **Database/Persistence:** Local File System (JSON) for notebooks, Apple Keychain for secure API key storage.
* **Architecture:** Modern Swift concurrency with a modular design pattern.

## 🚀 Getting Started
1. Clone the repository: `git clone https://github.com/lucaspanzera/ai-canvas.git`
2. Open the project in Xcode (requires Xcode 15+ and iOS/iPadOS 17+).
3. Build and run on your iPad Simulator or physical iPad.
4. On first launch, follow the onboarding process to add your preferred AI API Keys.

## 🤝 Contributing
Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Feel free to open issues or pull requests! 

---
Built with ❤️ by [Lucas Panzera](https://github.com/lucaspanzera)