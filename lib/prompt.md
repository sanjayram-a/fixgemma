# **Plan for redesigning the ui completely**

## **UI Flow**
  - when app opens a simple skeliton loading page.
  - in home screen no scrolling only shows app name at top without appbar setting screen adjacent to the name.
  - then show model card with two model one by one vertically with edge curved card design 
  - when the user selects a model go to page where there is full screen with text input and image input also audio input button bottom right corner.
  - the audio button takes the user to another page with mic button on center which is tap once to start recording and tap again to stop. and there is also image add button on bottom left corner.
  - so there is basically two input methods text and audio both have image input.
  - once user click start after prompting go to a loading page where the model is being loaded.
  - then generation started so the model needs to generate responce in the json structured format.
  - which is parsed when streaming from the model to update the ui.
  - first show the safety setting if exists in the response from the model.
  - then show the tools required by the model if exists in the response from the model.
  - then show the steps one by one in near card design.
  - if step 1 generated show that on the ui card.
  - then show the step 2 generated on the ui card.
  - shown on 
  - if the model still generating steps put a loading on next card.

## **UI DESIGNS**
### **homepage**
  - on top the app name fixgemma on right top corner and setting icon on left top corner.
  - then the model card with two model one by one vertically with edge curved card design.
  - then there is a nav bar at bottom which shows the home icon and history icon without any background or border.
  - use frosted glass effect for the model card and nav bar.
  - model card
    - 1st card shows model name fixgemma with correct size(gb).
    - description shows finetuned version gemma 4 e4b cactus version.
    - download icon when user clicks shows slide loading animation.
    - 2nd card shows model name fixgemma lite with correct size(gb).
    - description shows finetuned version gemma 4 e2b cactus version.
    - download icon when user clicks shows slide loading animation.

### **Prompting screen(Text + Image)**
  - in the centre of the screen shows the prompt text box.
  - there is a round + button on the left bottom corner inside the near adjacent to fix button.
  - above the box ask user what u r going to fix.
  - at bottom shows fix button curved edge design.

### **Prompting screen(voice + Image)**
  - in the centre of the screen shows the round mic icon button.
  - when user clicks there is a audio recording animation according to the voice.
  - when the recording is done, the audio can be played back and the user can listen to it.
  - there is a round + button on the left bottom corner inside the near adjacent to fix button.
  - when the user is satisfied with the audio, they can click the fix button to send the audio to the model and get a response.

### **response loading screen**
  - the loading animation(fourRotatingDots from loading_animation_widget: ^1.3.0)
  - the loading animation is placed above the card which is frosted glass which is slightly faded
  - show tiny text under the loading animation like model is initializing and response is being generated.

### **response screen**
  - top of the screen shows the user prompt and the model name.
  - and a card which is frosted glass on top of the card name which is like safety messages, tools required, step 1, step 2, tips etc.
  - and the response for that.
  - if one card loaded in json show the card first.
  - under the card at the bottom there is a right arrow button to go to the next card.
  - if next card is generating show the loading animation and tiny text under the loading animation like model is initializing and response is being generated.
  - under the card at the bottom there is a left arrow button to go to the previous card.
  - **note:** the card is horizontally scrollable one card is shown at display at a time. 
  - between the left and right arrow buttons there is a dot navigation indicator that shows the current card and the total number of cards(increase it when generating one by one).
  - when model finishes generating show one card at last with text input like any doubts the user might have.
  - if the user asks leave the card with text input like other generated cards and skips to new card generation, with same loading animation and tiny text under the loading animation.
  - then repeat the same process for the new card generation.

### **history screen**
  - history are shown in frosted glass edge curved cards.
  - each card is shown with a timestamp and the user can click on it to view the card.
  - user can delete a card from the history.
  - user can view cards in response page can be prompted to generate a new card.

### **Settings**
  - there is heading like "models", "customization", "accessibility".
  
  - **models**: 
    - list of available models
    - currently downloaded models
    - delete button to remove a model
  - **customization**: 
    - customize the model
    - temperature (default: 1)
    - top-p (default: 0.95) if cactus supports it.
    - top-k (default: 64) if cactus supports it.
    - max-tokens (default: 2048)
  - **accessibility**: 
    - text to speech (auto only reads text in the card not brackets in the json)

## **colors theme**
  - add floating slowly floating, blurred orbs in the background utilizing your Tertiary, Secondary, and Primary colors.
  - give small depth effects for cards.

  - **USE THESE COLORS**
    - Primary (Brand & Action): rgba(7, 132, 181)
      - Role: The anchor of your app. This is the highest-contrast color in your lineup.  
      - Usage: Primary Call-To-Action (CTA) buttons, vital typography (like large headers on light backgrounds), bottom navigation active icons, and primary branding elements.
    
    - Secondary (Interactive & Focus): rgba(57, 172, 231)
      - Role: The dynamic layer. It draws the eye without overpowering the primary brand color.
      - Usage: Hover states for primary buttons, active tabs, progress bars, toggle switches in the "on" position, and text links.
    
    - Tertiary (Support & Border): rgba(155, 212, 228)
      - Role: The structural divider. It provides visual separation without creating heavy, cluttered lines.
      - Usage: Inactive button states, subtle borders around cards or input fields, and backgrounds for informational banners (like "toast" notifications or tooltips).
    
    - Background (Support & Border): rgba(155, 212, 228)
      - Role: The base environment. Using a very pale blue instead of standard light gray or white gives the app a premium, bespoke feel.
      - Usage: The main scaffolding or background canvas of the application.
    
    - Surface / Highlight: rgba(255, 255, 255)
      - Role: The foreground layer and contrast anchor.
      - Usage: Card backgrounds floating above the pale blue canvas, modal windows, input field backgrounds, and text/icons placed inside your Primary blue buttons.

## **animations**
  - animations should be subtle(bg should be static or image added in future) and not overly distracting.
  - transtitions between screens should be smooth and not jarring.
  - add card transitions effect(cascade)
