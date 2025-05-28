## 0.0.1

### 🎉 Initial Release

#### ✨ Features
- **FCM Token Management**: Automatic token retrieval, refresh handling, and backend synchronization
- **Local Notifications**: Flutter Local Notifications integration for foreground message display
- **Smart Navigation**: Route-based navigation system with deep linking support
- **Backend Integration**: HTTP service with token registration, analytics, and preferences sync
- **Permission Management**: Cross-platform notification permission handling
- **Analytics Tracking**: Built-in event tracking for notification interactions
- **User Preferences**: Configurable notification categories and channel settings

#### 🏗️ Architecture
- **Layered Architecture**: Clean separation between Manager, Service, and Model layers
- **Singleton Pattern**: Memory-efficient single instance management
- **Stream-based**: Reactive programming with real-time event handling
- **Modular Design**: Independent service components for easy testing and maintenance

#### 📱 Platform Support
- **Android**: Full FCM support with local notifications
- **iOS**: Complete iOS integration with proper permission handling
- **Web**: Basic FCM web support through firebase_messaging_web

#### 🔧 Services
- **FcmService**: Core Firebase Messaging operations
- **NotificationService**: Local notification display and management
- **HttpService**: Backend communication and token management
- **NavigationService**: Smart routing and deep link handling

#### 🎯 Key Capabilities
- Foreground/background notification handling
- Automatic token refresh and backend sync
- Custom route handlers for navigation
- Analytics event tracking
- User preference management
- Logout and cleanup functionality
- Error handling and retry mechanisms

#### 📖 Documentation
- Comprehensive README with usage examples
- API reference documentation
- Integration guides for Android and iOS
- Notification payload structure guidelines
