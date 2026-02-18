//! Domain-specific error types for zmouse
//! Provides clear, typed errors for each subsystem

// ═══════════════════════════════════════════════════════════════════════
//  Input Errors
// ═══════════════════════════════════════════════════════════════════════

/// Errors that can occur during input operations (mouse/keyboard)
pub const InputError = error{
    /// SendInput Windows API call failed
    SendInputFailed,
    /// Coordinates are outside valid screen bounds
    InvalidCoordinates,
    /// Could not retrieve screen dimensions
    ScreenDimensionsInvalid,
    /// Could not get mouse cursor position
    GetPositionFailed,
    /// Invalid virtual key code
    InvalidKeyCode,
};

// ═══════════════════════════════════════════════════════════════════════
//  Recorder Errors
// ═══════════════════════════════════════════════════════════════════════

/// Errors that can occur during input recording
pub const RecorderError = error{
    /// Recorder not initialized before use
    NotInitialized,
    /// Recording already in progress
    AlreadyRecording,
    /// Failed to install Windows hook
    HookInstallationFailed,
    /// Failed to create hook thread
    ThreadCreationFailed,
    /// Failed to stop recording gracefully
    ThreadStopFailed,
    /// No events available for operation
    NoEvents,
    /// Memory allocation failed
    OutOfMemory,
};

// ═══════════════════════════════════════════════════════════════════════
//  Server Errors
// ═══════════════════════════════════════════════════════════════════════

/// Errors that can occur in the HTTP server
pub const ServerError = error{
    /// Winsock initialization failed
    WSAStartupFailed,
    /// Could not create socket
    SocketCreationFailed,
    /// Could not bind to port
    BindFailed,
    /// Could not listen on socket
    ListenFailed,
    /// Invalid HTTP request format
    InvalidRequest,
    /// Could not read from socket
    SocketReadFailed,
    /// Could not write to socket
    SocketWriteFailed,
    /// Server not running
    NotRunning,
    /// Port already in use
    PortInUse,
};

// ═══════════════════════════════════════════════════════════════════════
//  Storage Errors
// ═══════════════════════════════════════════════════════════════════════

/// Errors that can occur during file I/O
pub const StorageError = error{
    /// File not found
    FileNotFound,
    /// Permission denied
    PermissionDenied,
    /// Invalid JSON format
    InvalidJson,
    /// File path too long
    PathTooLong,
    /// File size invalid or too large
    FileSizeInvalid,
    /// Could not open file
    CannotOpenFile,
    /// Write operation failed
    WriteFailed,
    /// Read operation failed
    ReadFailed,
    /// JSON version mismatch
    VersionMismatch,
    /// Memory allocation failed
    OutOfMemory,
};

// ═══════════════════════════════════════════════════════════════════════
//  Screenshot Errors
// ═══════════════════════════════════════════════════════════════════════

/// Errors that can occur during screen capture
pub const ScreenshotError = error{
    /// Could not get screen dimensions
    ScreenDimensionsInvalid,
    /// Could not get device context
    GetDCFailed,
    /// Could not create compatible DC
    CreateCompatibleDCFailed,
    /// Could not create compatible bitmap
    CreateCompatibleBitmapFailed,
    /// BitBlt operation failed
    BitBltFailed,
    /// GetDIBits operation failed
    GetDIBitsFailed,
    /// Memory allocation failed
    OutOfMemory,
    /// BMP encoding failed
    BmpEncodingFailed,
    /// Base64 encoding failed
    Base64EncodingFailed,
};

// ═══════════════════════════════════════════════════════════════════════
//  Command Errors
// ═══════════════════════════════════════════════════════════════════════

/// Errors that can occur during command parsing
pub const CommandError = error{
    /// Unknown command
    UnknownCommand,
    /// Invalid command format
    InvalidFormat,
    /// Missing required argument
    MissingArgument,
    /// Invalid number in argument
    InvalidNumber,
    /// Invalid coordinate format
    InvalidCoordinates,
};

// ═══════════════════════════════════════════════════════════════════════
//  Combined Error Set
// ═══════════════════════════════════════════════════════════════════════

/// Union of all zmouse errors for convenience
pub const ZMouseError = InputError || RecorderError || ServerError || StorageError || ScreenshotError || CommandError;
