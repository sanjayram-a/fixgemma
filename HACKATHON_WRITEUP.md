# FixGemma: Gemma 4 Good Hackathon Writeup

## The Problem
When a household appliance breaks, getting a professional to fix it usually costs so much that people just throw it away and buy a new one. It's expensive for families and terrible for e-waste. We wanted to build something to fix that loop.

## Our Solution: FixGemma
FixGemma is an open-source AI assistant that runs entirely on your phone to help you repair broken appliances. You point your camera at the problem, describe what's wrong, and the app gives you a step-by-step repair guide. Since we're dealing with hardware, we also added strict safety instructions that pop up before suggesting fixes for anything electrical or hazardous. This felt like a perfect fit for the Gemma 4 Good hackathon.

## How We Built It
We wrote the app in Flutter. The actual reasoning is handled by Gemma 4 (we use both the e2b and e4b versions), running locally on the device using the Cactus AI inference engine.

1.  **On-Device AI:** We quantized Gemma 4 down to INT4 so it actually fits in phone RAM. It can process text, audio, and images without sending anything to the cloud.
2.  **Custom Dataset & Fine-Tuning:** I scraped together a custom 30k dataset from different repair sources. I fine-tuned both Gemma versions on this data before converting them for Cactus.
3.  **Carousel UI & JSON Parsing:** Instead of spitting out a wall of text, the app parses the AI's JSON output into a swipeable carousel of repair steps. If you get stuck on a specific step, you can ask a follow-up question right from that card.

## Challenges We Ran Into
*   **The RAM Wall:** Converting the models to Cactus required massive amounts of RAM—well over 30GB. My local machine couldn't handle it. We ended up moving the conversion process to Kaggle TPUs to get access to 300+ GB of memory, which finally let us compile the models.
*   **Phone Memory Limits:** Even after conversion, running multimodal models on consumer phones is tight. Relying on INT4 quantization saved the project.
*   **Structured Outputs:** We had to spend a lot of time fine-tuning the model and tweaking prompts just to get it to output consistent JSON. If the model broke the format, the carousel UI would crash.
*   **Data Prep:** Cleaning and formatting the 30k repair corpus took way longer than expected.

## Accomplishments We're Proud Of
*   Getting Gemma 4 to run completely offline. You don't need an internet connection to fix your stuff, and zero data leaves your phone.
*   The camera integration. Pointing your phone at a broken blender and asking "How do I fix this?" feels like magic when it works.
*   The interface. We spent a lot of time polishing the UI so it doesn't feel like a tech demo. It features smooth frosted-glass transitions and interactive carousel cards that generate step-by-step repair guides in real time.

## What We Learned
*   We finally figured out how to properly embed the Cactus AI engine inside a Flutter app.
*   We learned the hard way how much RAM model conversion actually takes, and how to use Kaggle TPUs to bypass hardware limits.
*   We got really good at parsing partial JSON streams into interactive UI components without blocking the main thread.
