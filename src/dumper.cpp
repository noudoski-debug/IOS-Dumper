#include "dumper.h"
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <vector>
#include <string>

// Il2Cpp runtime types
typedef void* (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef const char* (*il2cpp_image_get_name_t)(void* image);
typedef size_t (*il2cpp_image_get_class_count_t)(void* image);
typedef void* (*il2cpp_image_get_class_t)(void* image, size_t index);
typedef const char* (*il2cpp_class_get_name_t)(void* klass);
typedef const char* (*il2cpp_class_get_namespace_t)(void* klass);
typedef void* (*il2cpp_class_get_methods_t)(void* klass, void** iter);
typedef const char* (*il2cpp_method_get_name_t)(void* method);
typedef void* (*il2cpp_class_get_fields_t)(void* klass, void** iter);
typedef const char* (*il2cpp_field_get_name_t)(void* field);
typedef size_t (*il2cpp_field_get_offset_t)(void* field);
typedef void* (*il2cpp_field_get_type_t)(void* field);
typedef const char* (*il2cpp_type_get_name_t)(void* type);

static il2cpp_domain_get_t il2cpp_domain_get = nullptr;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = nullptr;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = nullptr;
static il2cpp_image_get_name_t il2cpp_image_get_name = nullptr;
static il2cpp_image_get_class_count_t il2cpp_image_get_class_count = nullptr;
static il2cpp_image_get_class_t il2cpp_image_get_class = nullptr;
static il2cpp_class_get_name_t il2cpp_class_get_name = nullptr;
static il2cpp_class_get_namespace_t il2cpp_class_get_namespace = nullptr;
static il2cpp_class_get_methods_t il2cpp_class_get_methods = nullptr;
static il2cpp_method_get_name_t il2cpp_method_get_name = nullptr;
static il2cpp_class_get_fields_t il2cpp_class_get_fields = nullptr;
static il2cpp_field_get_name_t il2cpp_field_get_name = nullptr;
static il2cpp_field_get_offset_t il2cpp_field_get_offset = nullptr;
static il2cpp_type_get_name_t il2cpp_type_get_name = nullptr;
static il2cpp_field_get_type_t il2cpp_field_get_type = nullptr;

static uintptr_t GetBaseAddress() {
    return (uintptr_t)_dyld_get_image_header(0);
}

static void ResolveIl2CppAPIs() {
    #define RESOLVE(name) name = (name##_t)dlsym(RTLD_DEFAULT, #name)
    RESOLVE(il2cpp_domain_get);
    RESOLVE(il2cpp_domain_get_assemblies);
    RESOLVE(il2cpp_assembly_get_image);
    RESOLVE(il2cpp_image_get_name);
    RESOLVE(il2cpp_image_get_class_count);
    RESOLVE(il2cpp_image_get_class);
    RESOLVE(il2cpp_class_get_name);
    RESOLVE(il2cpp_class_get_namespace);
    RESOLVE(il2cpp_class_get_methods);
    RESOLVE(il2cpp_method_get_name);
    RESOLVE(il2cpp_class_get_fields);
    RESOLVE(il2cpp_field_get_name);
    RESOLVE(il2cpp_field_get_offset);
    RESOLVE(il2cpp_type_get_name);
    RESOLVE(il2cpp_field_get_type);
    #undef RESOLVE
}

namespace Dumper {

void DumpIl2Cpp(const std::string& outDir) {
    ResolveIl2CppAPIs();
    if (!il2cpp_domain_get) {
        return;
    }

    mkdir(outDir.c_str(), 0755);

    std::string dumpCsPath = outDir + "/dump.cs";
    std::string scriptJsonPath = outDir + "/script.json";

    std::ofstream cs(dumpCsPath);
    std::ofstream json(scriptJsonPath);

    uintptr_t base = GetBaseAddress();

    json << "{\n  \"ScriptMethod\": [\n";
    bool firstMethod = true;

    void* domain = il2cpp_domain_get();
    if (!domain) return;

    size_t asmCount = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &asmCount);

    cs << "// Executable base: 0x" << std::hex << base << "\n\n";

    for (size_t i = 0; i < asmCount; ++i) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;

        const char* imgName = il2cpp_image_get_name(image);
        cs << "// Image: " << (imgName ? imgName : "unknown") << "\n";

        size_t classCount = il2cpp_image_get_class_count(image);
        for (size_t c = 0; c < classCount; ++c) {
            void* klass = il2cpp_image_get_class(image, c);
            if (!klass) continue;

            const char* ns = il2cpp_class_get_namespace(klass);
            const char* name = il2cpp_class_get_name(klass);

            cs << "namespace " << (ns ? ns : "") << " {\n";
            cs << "  class " << (name ? name : "Unknown") << " {\n";

            // Fields
            void* fieldIter = nullptr;
            while (void* field = il2cpp_class_get_fields(klass, &fieldIter)) {
                const char* fName = il2cpp_field_get_name(field);
                size_t offset = il2cpp_field_get_offset(field);
                void* fType = il2cpp_field_get_type(field);
                const char* tName = fType ? il2cpp_type_get_name(fType) : "void*";

                cs << "    // Offset: 0x" << std::hex << offset << "\n";
                cs << "    " << (tName ? tName : "var") << " " << (fName ? fName : "field") << ";\n";
            }

            // Methods
            void* methodIter = nullptr;
            while (void* method = il2cpp_class_get_methods(klass, &methodIter)) {
                const char* mName = il2cpp_method_get_name(method);
                void** methodPtr = (void**)method;
                uintptr_t methodAddr = methodPtr ? (uintptr_t)*methodPtr : 0;
                uintptr_t rva = methodAddr ? (methodAddr - base) : 0;

                cs << "    // RVA: 0x" << std::hex << rva << " (VA: 0x" << methodAddr << ")\n";
                cs << "    void " << (mName ? mName : "Method") << "();\n";

                if (methodAddr) {
                    if (!firstMethod) json << ",\n";
                    json << "    {\n";
                    json << "      \"AddressOffset\": " << std::dec << rva << ",\n";
                    json << "      \"Name\": \"" << (ns ? std::string(ns) + "." : "") << (name ? name : "") << "$$" << (mName ? mName : "") << "\",\n";
                    json << "      \"Signature\": \"void " << (mName ? mName : "") << "()\"\n";
                    json << "    }";
                    firstMethod = false;
                }
            }

            cs << "  }\n}\n\n";
        }
    }

    json << "\n  ],\n  \"ScriptString\": []\n}\n";
    cs.close();
    json.close();
}

} // namespace Dumper
