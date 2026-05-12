# FixGemma 🛠️

**AI-powered appliance repair assistant, built entirely on-device for the Gemma 4 Good Hackathon.**

FixGemma is a Flutter application that leverages **Gemma 4** (e2b & e4b models) via the **Cactus AI inference engine** to provide users with private, completely offline, multimodal repair assistance. By empowering people to repair their own appliances, FixGemma promotes sustainability, fights e-waste, and champions the "Right to Repair".

## 🌟 Features
*   **Fully On-Device Inference:** No internet required for AI generation. 100% private.
*   **Multimodal Inputs:** Describe the issue via text, record your voice, or take a picture of the broken appliance.
*   **Structured Output:** Generates step-by-step repair guides (safety warnings, tools required, steps, and tips) by streaming and parsing JSON in real-time.
*   **Background Downloads:** Robust management of large model weight downloads, ensuring completion even when the app is minimized.
*   **Beautiful UI:** Modern, responsive UI with frosted glass effects and card-based step-by-step navigation.

## 🏗️ Technical Stack
*   **Framework:** Flutter (Riverpod for state management, Hive for local storage)
*   **AI Engine:** Cactus AI inference engine
*   **Models:** 
    *   `fixgemma4-e4b-int4` (6.9 GB) - Finetuned version of gemma 4 e4b.
    *   `fixgemma4-e2b-int4` (4.0 GB) - Finetuned version of gemma 4 e2b.

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (>=3.3.0)
*   Android Studio / Xcode for device emulation
*   A physical device (recommended) with sufficient RAM and storage for on-device inference.

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/sanjayram-a/fixgemma.git
   cd fixgemma
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```
4. Upon first launch, navigate to settings to download your preferred Gemma 4 model or from home screen.

## 📖 Documentation
For a detailed overview of our Hackathon submission, problem statement, and technical challenges, please read the [Hackathon Writeup](HACKATHON_WRITEUP.md).