#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace Dumper {
    void Init();
    void DumpIl2Cpp(const std::string& outPath);
}
