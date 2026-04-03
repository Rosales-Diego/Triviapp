# Triviapp 🧠

Triviapp is a feature-rich, customizable trivia game built with Flutter. Challenge yourself across multiple categories, customize when you receive trivia questions, and track your performance with advanced local statistics.

## Features ✨

- **Diverse Categories**: Test your knowledge across a wide range of topics.
- **In-Depth Statistics**: Uses a robust local SQLite database to track your progress, win rates, and total correct/incorrect overall attempts.
- **Customizable Schedules**: Set up personalized schedules for different trivia categories. You can configure active days, start/end times, and the frequency of questions.
- **Configurable Difficulty**: Pick between Easy, Medium, and Hard difficulty levels per category.
- **Offline Tracking**: Your performance metadata, schedules, and analytics are seamlessly saved locally.

## Tech Stack 🛠

- [Flutter](https://flutter.dev/) - UI framework
- [Dart](https://dart.dev/) - Programming language
- [sqflite](https://pub.dev/packages/sqflite) - Local relational database for schedule and analytics storage
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Local key-value storage

## Getting Started 🚀

To run this project locally, ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.

1. Clone the repository and navigate to the directory:
   ```bash
   cd triviapp
   ```
2. Fetch the project dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application on your preferred device/emulator:
   ```bash
   flutter run
   ```

## Data Attribution & License ⚖️

This application utilizes the [Open Trivia Database (OpenTDB)](https://opentdb.com/) API to source its trivia questions and categories. 

In compliance with the API provider's requirements, all trivia data (questions, answers, categories) provided by OpenTDB is licensed under the **[Creative Commons Attribution-ShareAlike 4.0 International License (CC BY-SA 4.0)](https://creativecommons.org/licenses/by-sa/4.0/)**.

Under this license, you are free to:
- **Share** — copy and redistribute the material in any medium or format.
- **Adapt** — remix, transform, and build upon the material for any purpose, even commercially.

As long as you follow these terms:
- **Attribution** — You must give appropriate credit, provide a link to the license, and indicate if changes were made.
- **ShareAlike** — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
