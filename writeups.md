## **Inspiration**
The world generates about 170,000 tonnes of e-waste per day. Most of it is thrown away because it is hard to repair by ourselves or expensive to hire professionals.

AI is helping to solve most of the problems today, but flagship models come with limitations. Most of them look like regular chatbots and require internet. In rural areas, reliable internet connections are often not available.

We strongly believe in the **Right to Repair** and everyone needs a solution that works regardless of internet and even on budget mobiles. 

I love doing DIY repairs and projects myself, but I always felt something was missing - a reliable companion to guide me through the process. So we built FixGemma - AI Repair Assistant.

there are many AI apps that fails because of they prioritize conversational ui over efficient, task-oriented experience.
so we build app with a new Carousel UI to make difference.

## **FixGemma**
FixGemma is a mobile app that gives you step-by-step visual instructions through visual carousel to help you fix your appliances and DIY projects.

The app uses a Fine-tuned version of **Gemma 4** models to generate repair instructions and locally run the inference on the device.
as we have seen about the Gemma 4 multimodel capabilities so we can provide multiple types of input like text, images, and audio to generate more accurate repair instructions.

We used the Cactus inference engine to enable hybrid inference. which routes the task to cloud model seemlessly when the task is complex.

## **Development Process**
1. we started with collecting data from web and other related datasets. the dataset we selected had many anomolies so we used a embedding model to guess semantic scores between the data points and datasets to get more similar data and prepared a 30k corpus dataset.
2. we also tried to curate the dataset by batch feeding it to a llm to get more structured and added safety informations. However, because our dataset was 30k entries and we had limited resources, we could not curate it fully. We managed to curate 1k results, which we then combined with the uncurated dataset. This gave the model more diversity and accurate repair instructions.
3. then we started lora fine-tuning the both **gemma 4 e4b** and **gemma 4 e2b** models on our curated dataset with **Unsloth**. we used the same training setup and hyperparameters for both models to ensure consistency.
4. we started with gemma 4 e4b model and fine-tuned it first, the results were satisfied. then we fine-tuned gemma 4 e2b model on the same dataset to ensure for maximum device compatibility. then we merged the lora adapters to the base models and converted them to gguf format.
5. then we researched little bit and selected **cactus** for inference the model locally on device. there is a problem with in their new version they removed support for gguf format. and their new version needs native **.cact** format.
6. so now we need to convert the model to .cact format which is new for us. so we researched little bit further and learned about cactus tools. then we tried to convert the gemma 4 e4b merged 16bit model to .cact format using the cactus cli tool. we debugged the conversion process for almost 24 hours to get it working. then when it starts conversion, we hit a kaggle RAM limit because the model need almost 32gb of RAM to convert so everything crashed. after hitting google for an hour we found-out kaggle TPU session which gives 300+gb of RAM and we tried and converted the model to INT4 quantized .cact format successfully.
7. then we done the same for gemma 4 e2b model and converted it to INT4 quantized .cact format successfully.
8. we started building the first working prototype if the app with basic inference capabilities. started with a simple chat interface to test the model inference. we can both e4b and e2b models on a $100 budget phone. which was our biggest accompanishment.
9. fitting a gigabyte model in a app bundle was impossible so we made a downloading option to the app which can download the model from the hugging face model hub in high speed. 
10. then we started improving the app by adding features like model selection, chat history, text to speech options, model configuration like temperature, top-p sampling, top-k sampling and a settings menu. i personally hate chat interfaces in this type of app. to make difference we introduced a carousel interface for the model responce and finalized the app.

## **Fine-tuning**
1. 

## **Why Cactus?**
1. i tested both **LiteRT** and **Cactus** with my budget phone, i found-out that the model loads 2x faster with Cactus than LiteRT and consumes 10x less memory thanks for the cactus zero-copy memory mapping technique and consumes less battery.
2. the cactus also supports Gemma 4's multi-modal capabilities which is must needed for this app.
3. can be easily integrated with flutter for cross-platform development.
4. it supports NPU and CPU for inference.
5. if the low end device hits with a heavy prompt it detects the bottleneck and it automatically splits processing and hand-off to the cloud model in the mid stream.

## **Features**
1. safety

## **Challenges**
1. cact conversion

1. To be continued...



<p>Thanks for the contribution <a href="https://www.kaggle.com/renuka7812">@Renuka S</a>,</p>
