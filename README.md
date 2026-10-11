# Memories 📍

### Your life, mapped.

Memories is a private, location-based memory journal built with **Flutter** and **Supabase**. It lets you save moments to places on a map and revisit them through an immersive, story-style viewer.

Instead of keeping photos scattered across your gallery, Memories connects them to the places and moments that matter to you.

**Map → Memory Preview → Story Viewer**

---

## ✨ Features

- **Interactive Memory Map**  
  Explore saved memories on a dark map with circular photo markers, selection states and marker clustering.

- **Create Memories**  
  Save moments with multiple photos, videos, voice recordings, dates and locations.

- **Immersive Story Viewer**  
  Browse memory media in sequence with tap navigation, press-and-hold controls, automatic progression and favourites.

- **Memories Timeline**  
  Browse your saved moments and filter your collection.

- **Search**  
  Find memories within your collection.

- **Profile Management**  
  Manage your profile, upload an avatar, edit your name and view memory statistics.

- **Authentication**  
  Sign up, log in, log out and maintain your authenticated session.

- **Location Selection**  
  Use your current location or choose a place for a memory.

- **Media Management**  
  Reorder media, record voice notes, track upload progress and handle failed uploads.

- **Private Media Storage**  
  Media buckets remain private.The app stores storage paths and uses short-lived signed URLs to access media.

- **Account Management**  
  Includes an account deletion feature.

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| Flutter & Dart | Mobile application |
| Supabase Auth | User authentication |
| Supabase Database | Memory and profile data |
| Supabase Storage | Private photo, video, and audio storage |
| `flutter_map` | Interactive map |
| OpenStreetMap / CARTO | Map data and dark map styling |
| Geolocator & Geocoding | Location-related features |
| Docker | Reproducible Android APK builds |

---

## 🏗️ Application Flow

1. **Authenticate** to access your account.
2. **Explore the map** to see memories attached to locations.
3. **Select a memory** to open its preview.
4. **Open the story viewer** to browse its photos, videos, and voice recordings.
5. **Create and manage memories** through the app's creation screen, timeline, search and profile sections.

---

## 🚀 Getting Started

### Option 1: Build with Docker (Android)

Docker Desktop is the recommended build method for this repository.You do not need a local Flutter installation.

**Prerequisites**
- Windows, macOS or Linux
- Docker Desktop or a compatible Docker Engine with Compose
- A configured Supabase project

#### 1. Clone the repository

```bash
git clone https://github.com/Jeet-Sodha/Memories.git
cd Memories
```

#### 2. Configure Supabase

Open:

```text
lib/config/supabase_config.dart
```

Set your Supabase project URL and publishable key:

```dart
static const String url = 'https://YOUR_PROJECT.supabase.co';
static const String publishableKey = 'YOUR_SUPABASE_PUBLISHABLE_KEY';
```

Use the project's **publishable key**.Never put a Supabase secret key or service-role key in the Flutter application.

#### 3. Build the Docker image

```bash
docker compose build
```

#### 4. Build the Android APK

```bash
docker compose run --rm memories
```

The generated APK is saved to:

```text
output/memories.apk
```

#### 5. Analyze the Dart code

```bash
docker compose run --rm memories analyze
```

The first build may take several minutes while Android and Gradle dependencies are downloaded.Subsequent builds can reuse Docker's cached dependencies.

**Install on an Android device**

Transfer `output/memories.apk` to your phone and open it, allowing installation from that source if Android requests permission.

Alternatively, with USB debugging enabled and Android Debug Bridge installed:

```bash
adb install -r output/memories.apk
```

### Option 2: Run with Flutter installed

A local Flutter environment is an alternative for development and platform-specific testing.

1. Install Flutter and the Android or iOS development tools.
2. Create a Flutter project with Android and iOS platform folders.
3. Copy this repository's `lib/` directory into the project.
4. Add the dependencies listed in the project's `pubspec.yaml` or the setup instructions below.
5. Configure Supabase and run the platform configuration helper.
6. Start the app using `flutter run`.

The Docker workflow is currently focused on Android. **Building for iOS requires macOS, Xcode and the appropriate Apple development setup.**

---

## 🔐 Supabase Setup

Memories relies on Supabase for authentication, database records, and media storage.

Before testing the app, ensure that your Supabase project has:

- Email authentication enabled.
- The required database tables and policies configured.
- The storage buckets used by the application created.
- Appropriate Row Level Security (RLS) policies for private user data.
- Private media buckets and suitable storage access policies.

SQL helper files are available in the `supabase/` directory.Review each script and understand its effects before executing it in the Supabase SQL Editor.Do not run scripts blindly against a production database.

### Privacy approach

Memories stores media paths rather than permanent public media URLs.When media needs to be displayed, the app uses short-lived signed URLs.

**Important:** Private buckets and signed URLs are part of the access-control design, but actual privacy also depends on correct database policies, storage policies and application authorization.

---

## 📁 Project Structure

```text
Memories/
├── assets/
│   └── app_icon.png
├── docker/
│   └── build.sh
├── lib/
│   ├── config/
│   ├── models/
│   ├── screens/
│   ├── services/
│   ├── state/
│   ├── theme/
│   ├── utils/
│   ├── widgets/
│   └── main.dart
├── supabase/
│   ├── delete_account.sql
│   └── memory_media_update_policy.sql
├── tools/
│   ├── apply_branding.py
│   └── apply_platform_config.py
├── .dockerignore
├── .gitignore
├── Dockerfile
├── docker-compose.yml
├── README.md
└── CHANGES.md
```

Flutter's `android/` and `ios/` platform directories are generated as part of project setup and are not included in this repository's current source layout.

---

## 📱 Platform Support

| Platform | Status |
|---|---|
| Android | APK build supported through Docker |
| iOS | Requires macOS, Xcode and platform setup |
| Web | Not currently supported as a complete web application |

The app uses mobile-oriented features such as camera-roll access, media selection, recording and location services.

---

## 🧭 Design

The interface follows the **Midnight** visual direction from the project's Stitch designs, using a dark theme and a map-first experience.

The goal is to make saved moments feel connected to real places, while keeping the experience focused on browsing, creating and revisiting memories.

---

## 🚧 Scope

The current implementation focuses on private, location-based memory keeping.

Features such as memory trails and social interactions are outside the current scope.Tags and music features are also not included in the current data model.

---

## 👨‍💻 Development

Contributions, bug reports and suggestions are welcome.Before proposing changes, please:

1. Describe the issue or improvement.
2. Keep changes focused on the relevant feature.
3. Test the Android build after modifying the code.
4. Avoid committing generated APKs, credentials or local build artifacts.

---

**Memories**  
*Your life, mapped*
