// logging.cpp - Logging system for WoWTranslate

#include <windows.h>
#include <string>
#include <fstream>
#include <iostream>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <mutex>

#include "../include/logging.h"
#include "../include/utils.h"

using namespace std;

// Global logging state
static bool g_loggingInitialized = false;
static string g_logFilePath;
static mutex g_logMutex;

bool InitializeLogging() {
    lock_guard<mutex> lock(g_logMutex);

    if (g_loggingInitialized) {
        return true;
    }

    try {
        // Get the DLL directory
        string dllPath = GetDllPath();
        if (dllPath.empty()) {
            return false;
        }

        // Extract directory from DLL path
        size_t lastSlash = dllPath.find_last_of("\\/");
        string dllDir = dllPath.substr(0, lastSlash);

        // Create log file path
        g_logFilePath = dllDir + "\\WoWTranslate_debug.log";

        // Test if we can write to the log file
        ofstream testFile(g_logFilePath, ios::app);
        if (!testFile.is_open()) {
            return false;
        }

        // Write initialization message
        testFile << "\n" << string(60, '=') << "\n";
        testFile << "WoWTranslate v0.1 initialized at " << GetCurrentTimestamp() << "\n";
        testFile << string(60, '=') << "\n";
        testFile.close();

        g_loggingInitialized = true;
        return true;

    } catch (...) {
        return false;
    }
}

void CleanupLogging() {
    lock_guard<mutex> lock(g_logMutex);

    if (!g_loggingInitialized) {
        return;
    }

    try {
        // Write cleanup message
        ofstream logFile(g_logFilePath, ios::app);
        if (logFile.is_open()) {
            logFile << "[" << GetCurrentTimestamp() << "] [INFO] WoWTranslate cleanup complete\n";
            logFile << string(60, '=') << "\n\n";
            logFile.close();
        }
    } catch (...) {
        // Ignore errors during cleanup
    }

    g_loggingInitialized = false;
}

void LogToFile(LogLevel level, const string& message) {
    if (!g_loggingInitialized) {
        return;
    }

    lock_guard<mutex> lock(g_logMutex);

    try {
        ofstream logFile(g_logFilePath, ios::app);
        if (!logFile.is_open()) {
            return;
        }

        // Get level string
        string levelStr;
        switch (level) {
            case LogLevel::Info: levelStr = "INFO"; break;
            case LogLevel::Warning: levelStr = "WARN"; break;
            case LogLevel::Error: levelStr = "ERROR"; break;
            case LogLevel::Debug: levelStr = "DEBUG"; break;
        }

        // Write log entry
        logFile << "[" << GetCurrentTimestamp() << "] [" << levelStr << "] " << message << "\n";
        logFile.close();

    } catch (...) {
        // Ignore logging errors to prevent cascading failures
    }
}
