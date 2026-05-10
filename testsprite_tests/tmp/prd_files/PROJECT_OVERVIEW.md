# Vivechana (विवेचना) - Project Overview

## 📖 Purpose
Vivechana is a comprehensive digital platform designed to serve as a high-quality Hindi literary magazine, news aggregator, and collaborative writer's space. Its primary goal is to bridge the gap between quality Hindi journalism, contemporary literature, and digital accessibility by offering readers a single ecosystem to consume curated news, read the digital magazine, and discover original contributions from independent writers.

***

## ✨ Core Features

### 1. Hindi News Aggregator (समाचार)
- **Multi-source RSS Integration**: Automatically fetches and aggregates news from reliable sources like BBC News Hindi and Bing News RSS feeds.
- **Categorized Feeds**: Supports a wide array of categories including National (भारत), International (विश्व), Tech (टेक्नोलॉजी), Sports (खेल), Business (अर्थव्यवस्था), and Entertainment (मनोरंजन).
- **Smart Formatting & Media Handling**: The app actively parses and cleans up raw HTML boilerplate from RSS feeds to provide distraction-free reading. It includes a fallback subsystem that auto-assigns relevant, high-quality stock imagery based on topic keywords in the headline (e.g., politics, weather) if the original source lacks a cover photo.
- **Trending Topics**: Analyzes current fetched news to surface live trending keywords natively.

### 2. Independent Writers Platform (रचनाकार मंच)
- **Collaborative Community**: Authenticated users can register as writers to draft and submit their own literary pieces, such as articles (लेख), memoirs (संस्मरण), and poetry.
- **Interactive Engagement**: Community-driven interaction system that supports likes, view counters, and hierarchical comment threads on user-generated articles.
- **Content Moderation**: Built-in reporting system allowing readers to flag inappropriate comments or content. Admins can moderate these reports.
- **Media Management**: Features automatic client-side image compression before uploading article covers to Firebase Storage, ensuring fast load times and optimized cloud costs.

### 3. Digital Magazine (ई-पत्रिका)
- **Integrated PDF Viewing**: Readers can access and read the official monthly/periodic editions of the Vivechana magazine natively within the app without relying on external document viewers.
- **Reading History & Bookmarks**: Users can track their 'recently read' history and save their favorite magazine editions or articles for offline access or later reading.

### 4. Admin Dashboard (व्यवस्थापक)
- **Approval Workflows**: Dedicated dashboard allowing admins to screen, approve, or reject user-submitted articles to maintain high editorial standards. Admin actions natively trigger notifications back to the authors.
- **Content Operations**: Admins can publish new magazine editions, upload digital media/news reels, and monitor the overall health of the platform through user activity reports.

***

## 🛠️ Technological Architecture

- **Framework**: Developed natively in Flutter (`sdk: ^3.10.4`), compiling to a smooth mobile experience tailored for both Android and iOS.
- **Backend as a Service (BaaS)**: Fully powered by Google Firebase ecosystem:
  - **Firebase Auth**: Manages secure user authentication, including OAuth with Google Sign-in.
  - **Cloud Firestore**: Real-time NoSQL database handling structured schemas for users, writer_articles, magazines, comments, and analytics.
  - **Firebase Storage**: Handles static asset hosting for profile pictures, magazine PDFs, and writer cover photos.
- **State Management & UI**: Relies heavily on the `provider` package for clean widget tree state management, `shimmer` for skeleton loading animations, `animate_do` for micro-interactions, and `google_fonts` for typography.
- **Background Processes**: Integrates `workmanager` and `flutter_local_notifications` for scheduled background tasks and push-style alert delivery.
- **Rich Media**: Leverages `youtube_player_flutter` and `video_player` for embedded multimedia playback and `syncfusion_flutter_pdfviewer` for the digital magazine.

***

## 🔄 How It Works (Application Flow)

1. **Onboarding & Auth**: A user opens the app, lands on an aesthetically pleasing onboarding track, and logs in seamlessly (typically via Google or Email/Password).
2. **Dashboard Delivery**: The authenticated user is routed to the Home Page, displaying an algorithmic mix of the newest Vivechana Magazine issue, breaking news, and trending community-written articles.
3. **News Pipeline**: The `NewsService` fetches XML data from RSS sources in real-time, caches it for 2 minutes to reduce network usage, extracts exact body contents from `<html>` tags, assigns an image, and serves it to the `NewsPage`.
4. **Writing Lifecycle**:
   - A reader wants to write -> navigates to profiles -> 'Register as Writer'
   - Drafts an article with formatted text (`flutter_quill`) -> Attaches a cover image -> Submits.
   - The article enters Firestore with `status: pending`.
   - Admin logs in, accesses the dashboard, reads the draft, and clicks 'Approve'.
   - The article transitions to `status: approved` and is immediately pushed to all users' public `Writer Feed`, notifying the author of their successful publication.
