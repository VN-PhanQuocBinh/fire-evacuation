/**
 * Module: 2_grid_rasterizer.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: LỚP MA TRẬN GRID CELL phủ lên mặt bằng 2D
 *   - Rasterize từ plan_element (etype) sang các cờ trạng thái:
 *       is_origin    : ô khởi phát cháy (Tủ lạnh Hotpoint - ORIGIN)
 *       is_window    : ô cửa sổ mặt ngoài (facade_window)
 *       is_cladding  : ô lớp ốp mặt ngoài tháp (outer_wall)
 *       is_stairwell : ô buồng thang bộ (stair_box)
 *       is_obstacle  : ô tường đặc / cột (wall, column, outer_wall, riser)
 *   - Tương thích hoàn toàn với 3_fire_cladding_dynamics.gaml
 *   - Tương thích GAMA 2025.6.4
 *
 * Grid: 100 × 75 ô, khớp chính xác 1:1 với kích thước 100 × 75 của mô hình (1 ô = 1.0 × 1.0 m)
 */

model grid_rasterizer

import "1_building_architecture.gaml"

// Lưới ô ma trận
// 100 x 75
// 200 x 150
// 300 x 225
grid grid_cell width: 300 height: 225 neighbors: 8 {
    // --- CỜ KIẾN TRÚC (ánh xạ từ plan_element.etype) ---
    bool is_origin    <- false;   // Điểm phát cháy ban đầu
    bool is_window    <- false;   // Cửa sổ (lan cháy ra ngoài mặt dựng)
    bool is_cladding  <- false;   // Lớp ốp mặt ngoài (cladding)
    bool is_stairwell <- false;   // Buồng thang bộ thoát hiểm
    bool is_obstacle  <- false;   // Vật cản rắn (tường, cột, riser)

    // --- TRẠNG THÁI LỬA & KHÓI (dùng bởi module 3) ---
    bool  burning       <- false;
    float fire_power    <- 0.0;    // 0.0 – 1.0
    bool  smoky         <- false;
    float smoke_density <- 0.0;    // 0.0 – 1.0

    // Thuộc tính màu mặc định
    rgb color <- #transparent;

    // Aspect: CHỈ HIỂN THỊ KHI Ô CÓ LỬA HOẶC KHÓI, tránh che mờ bản vẽ kiến trúc
    aspect default {
        if (burning or smoky) {
            draw shape color: color;
        }
    }
}

global {
    // Hành động rasterize: ánh xạ plan_element → grid_cell flags
    // Gọi sau khi build_active_floor_plan() hoàn thành
    action rasterize_floor_plan {
        // Reset tất cả cờ và màu trước
        ask grid_cell {
            is_origin     <- false;
            is_window     <- false;
            is_cladding   <- false;
            is_stairwell  <- false;
            is_obstacle   <- false;
            burning       <- false;
            fire_power    <- 0.0;
            smoky         <- false;
            smoke_density <- 0.0;
            color         <- #transparent;
        }

        // Tối ưu: Chỉ quét các ô grid nằm trong vùng mặt bằng bên phải (x: 48 -> 94, y: 15 -> 61)
        list<grid_cell> floor_cells <- grid_cell where (each.location.x >= 48.0 and each.location.x <= 94.0 and each.location.y >= 15.0 and each.location.y <= 61.0);

        // Ánh xạ từng plan_element sang các ô grid tương ứng
        ask plan_element {
            string t <- self.etype;

            // Xác định loại cờ cần set
            bool flag_obstacle  <- (t = "wall" or t = "outer_wall" or t = "column" or t = "riser");
            bool flag_origin    <- (t = "origin_fridge");
            bool flag_window    <- (t = "facade_window");
            bool flag_cladding  <- (t = "outer_wall");
            bool flag_stairwell <- (t = "stair_box");

            if (flag_obstacle or flag_origin or flag_window or flag_cladding or flag_stairwell) {
                list<grid_cell> overlapping <- floor_cells overlapping self.shape;
                ask overlapping {
                    if (flag_obstacle)  { is_obstacle  <- true; }
                    if (flag_origin)    { is_origin    <- true; }
                    if (flag_window)    { is_window    <- true; }
                    if (flag_cladding)  { is_cladding  <- true; }
                    if (flag_stairwell) { is_stairwell <- true; }
                }
            }
        }

        write "[Grid Rasterizer] Rasterize hoàn tất: "
            + length(grid_cell where each.is_obstacle)  + " obstacle, "
            + length(grid_cell where each.is_origin)    + " origin, "
            + length(grid_cell where each.is_window)    + " window, "
            + length(grid_cell where each.is_stairwell) + " stairwell, "
            + length(grid_cell where each.is_cladding)  + " cladding cells.";
    }
}
