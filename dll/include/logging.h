#pragma once

#include <string>

// Log levels
enum class LogLevel {
    Info = 0,
    Warning = 1,
    Error = 2,
    Debug = 3
};

// Logging functions
bool InitializeLogging();
void CleanupLogging();
void LogToFile(LogLevel level, const std::string& message);

// Convenience macros
#define LOG_INFO(msg) LogToFile(LogLevel::Info, msg)
#define LOG_WARNING(msg) LogToFile(LogLevel::Warning, msg)
#define LOG_ERROR(msg) LogToFile(LogLevel::Error, msg)
#define LOG_DEBUG(msg) LogToFile(LogLevel::Debug, msg)
