#include <librobot/librobot.h>

#include <iostream>
#include <sstream>

int main() {
  std::ostringstream capturedOutput;
  std::ostringstream capturedError;
  std::streambuf *const originalOutput = std::cout.rdbuf(capturedOutput.rdbuf());
  std::streambuf *const originalError = std::cerr.rdbuf(capturedError.rdbuf());

  {
    libRobot robot;
  }

  std::cout.rdbuf(originalOutput);
  std::cerr.rdbuf(originalError);
  if (!capturedOutput.str().empty() || !capturedError.str().empty()) {
    std::cerr << "Construction/destruction emitted output. stdout: "
              << capturedOutput.str() << " stderr: " << capturedError.str();
    return 1;
  }
  return 0;
}
