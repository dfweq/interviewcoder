# Interview Coder

Interview Coder is a macOS application designed to help developers practice and solve coding interview problems. It uses OpenAI's GPT-4o to analyze screenshots of coding problems and generate optimal solutions with detailed explanations.

## Demo

https://github.com/user-attachments/assets/5775d382-21e7-441b-8901-3a37c6b17a61



## Features

- **Screenshot Capture**: Easily capture coding problems from any source
- **AI-Powered Analysis**: Uses OpenAI's GPT-4o to analyze problems and generate solutions
- **Multiple Languages**: Supports Python, JavaScript, Java, C++, Go, Ruby, and Swift
- **Floating Interface**: Stays on top of other windows and can be toggled with keyboard shortcuts
- **Detailed Solutions**: Provides problem statement, approach, code, and complexity analysis
- **Debug Mode**: Can analyze your attempted solutions and provide improvements

## System Requirements

- macOS 11.0 (Big Sur) or later
- OpenAI API key

## Installation

1. Download the latest release from the releases page
2. Move the application to your Applications folder
3. Launch the application and provide your OpenAI API key when prompted

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd+H** | Take a screenshot of the current problem |
| **Cmd+B** | Toggle window visibility |
| **Cmd+Return** | Process the captured screenshots |
| **Cmd+R** | Reset (clear all screenshots) |
| **Cmd+G** | Regenerate solution |
| **Cmd+Arrow Keys** | Move the window |
| **Cmd+0** | Reset to compact view |

### Workflow

1. Navigate to your coding problem (e.g., LeetCode, HackerRank, etc.)
2. Press **Cmd+H** to capture a screenshot of the problem
3. Press **Cmd+Return** to process the screenshot
4. Review the solution provided in the expanded window

The application will display:
- Problem statement (extracted from the screenshot)
- Approach (logical steps to solve the problem)
- Solution code in your selected language
- Time and space complexity analysis

### API Key Management

Your OpenAI API key is required to use the application. It is stored securely in the system's UserDefaults. You can update your API key at any time by clicking the "Update API Key" button in the interface.

## Architecture

Interview Coder is built with SwiftUI and uses the following components:

- **ScreenCaptureKit**: For capturing screenshots
- **SwiftUI**: For the user interface
- **OpenAI API**: For analyzing problems and generating solutions
- **Carbon**: For global hotkey registration

## Privacy

Interview Coder sends screenshots to OpenAI's servers for analysis. Please ensure you do not capture sensitive information. Your API key is stored locally and is only used to authenticate requests to OpenAI's API.

## Troubleshooting

### Common Issues

- **Permission Denied**: Make sure to grant screen recording permission to the app in System Preferences > Privacy & Security > Screen Recording
- **Invalid API Key**: Ensure your OpenAI API key is correct and has access to GPT-4o
- **No Solution Generated**: Ensure the screenshot clearly shows the entire problem, including all constraints and examples

## License

GNU

## Acknowledgements

This application uses the OpenAI API to provide intelligent code solutions. It requires an active OpenAI API key with access to the GPT-4o model.

This project was inspired by [interview-coder](https://github.com/ibttf/interview-coder)
