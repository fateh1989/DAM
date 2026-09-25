#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class DAMNativeCore : public RefCounted {
    GDCLASS(DAMNativeCore, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary analyze_cells(
        const PackedInt32Array &levels,
        int32_t grid,
        int32_t cliff_min_levels
    ) const;

    String engine_tag() const;
};

} // namespace godot
