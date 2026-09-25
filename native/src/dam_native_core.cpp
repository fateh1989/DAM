#include "dam_native_core.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void DAMNativeCore::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD("analyze_cells", "levels", "grid", "cliff_min_levels"),
        &DAMNativeCore::analyze_cells
    );
    ClassDB::bind_method(D_METHOD("engine_tag"), &DAMNativeCore::engine_tag);
}

Dictionary DAMNativeCore::analyze_cells(
    const PackedInt32Array &levels,
    int32_t grid,
    int32_t cliff_min_levels
) const {
    Dictionary result;

    if (grid <= 0) {
        result["averages"] = PackedInt32Array();
        result["slopes"] = PackedInt32Array();
        result["cliff_edges"] = 0;
        result["native"] = true;
        return result;
    }

    const int64_t stride = static_cast<int64_t>(grid) + 1;
    const int64_t expected = stride * stride;
    if (levels.size() < expected) {
        result["averages"] = PackedInt32Array();
        result["slopes"] = PackedInt32Array();
        result["cliff_edges"] = 0;
        result["native"] = true;
        return result;
    }

    PackedInt32Array averages;
    PackedInt32Array slopes;
    const int64_t cell_count = static_cast<int64_t>(grid) * grid;
    averages.resize(cell_count);
    slopes.resize(cell_count);

    for (int32_t gy = 0; gy < grid; ++gy) {
        for (int32_t gx = 0; gx < grid; ++gx) {
            const int64_t i00 = static_cast<int64_t>(gy) * stride + gx;
            const int64_t i10 = i00 + 1;
            const int64_t i01 = i00 + stride;
            const int64_t i11 = i01 + 1;

            const int32_t l00 = levels[i00];
            const int32_t l10 = levels[i10];
            const int32_t l01 = levels[i01];
            const int32_t l11 = levels[i11];

            const int64_t sum =
                static_cast<int64_t>(l00) + l10 + l01 + l11;
            const int32_t avg = static_cast<int32_t>(
                std::lround(static_cast<double>(sum) * 0.25)
            );

            const int32_t diagonal_a = std::abs(l00 - l11);
            const int32_t diagonal_b = std::abs(l10 - l01);
            const int32_t edge_a = std::abs(l00 - l10);
            const int32_t edge_b = std::abs(l00 - l01);
            const int32_t slope = std::max(
                std::max(diagonal_a, diagonal_b),
                std::max(edge_a, edge_b)
            );

            const int64_t index = static_cast<int64_t>(gy) * grid + gx;
            averages[index] = avg;
            slopes[index] = slope;
        }
    }

    int64_t cliff_edges = 0;
    for (int32_t gy = 0; gy < grid; ++gy) {
        for (int32_t gx = 0; gx < grid; ++gx) {
            const int64_t index = static_cast<int64_t>(gy) * grid + gx;
            const int32_t here = averages[index];

            if (gx + 1 < grid) {
                const int32_t east = averages[index + 1];
                if (std::abs(here - east) >= cliff_min_levels) {
                    ++cliff_edges;
                }
            }

            if (gy + 1 < grid) {
                const int32_t south = averages[index + grid];
                if (std::abs(here - south) >= cliff_min_levels) {
                    ++cliff_edges;
                }
            }
        }
    }

    result["averages"] = averages;
    result["slopes"] = slopes;
    result["cliff_edges"] = cliff_edges;
    result["native"] = true;
    return result;
}

String DAMNativeCore::engine_tag() const {
    return "DAM Native Core v1 / C++ GDExtension / Godot 4.7";
}
