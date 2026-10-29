/**
 * Name: main.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: FILE ĐIỀU KHIỂN CHÍNH — Grenfell Tower Modular Simulation
 *
 *   Kiến trúc module:
 *     1_building_architecture.gaml  → Mặt đứng 25 tầng & Mặt bằng 2D
 *     2_grid_rasterizer.gaml        → Lớp lưới Grid Cell + ánh xạ cờ kiến trúc
 *     3_fire_cladding_dynamics.gaml → Lửa & Khói (Dual-Layer & Sequence-based Spread)
 *     4_people_evacuation.gaml      → Con người & Sơ tán (placeholder)
 *
 *   Tương thích: GAMA 2025.6.4
 */

model main

import "includes/4_people_evacuation.gaml"

global {
    // Kích thước môi trường toàn cục cố định (100m × 75m)
    geometry shape <- rectangle(100.0, 75.0) at_location {50.0, 37.5};

    init {
        write "=== KHỞI TẠO MÔ HÌNH GRENFELL TOWER (MODULAR DUAL-LAYER) ===";

        // 1. Dựng bản vẽ kiến trúc (mặt đứng bên trái + mặt bằng bên phải)
        do build_tower_elevation;
        do build_active_floor_plan;

        // 2. Rasterize bản vẽ vector → Grid Cell flags
        do rasterize_floor_plan;

        // 3. Khởi tạo module sơ tán
        do init_evacuation_module;

        // 4. Trang trí giao diện (tiêu đề, phân cách, nhãn)
        create screen_decor with: [dtype: "header",
            label: "GRENFELL TOWER FIRE & CLADDING SIMULATION (DUAL-LAYER 25 FLOORS)",
            location: {50.0, 3.2}];
        create screen_decor with: [dtype: "separator",
            shape: polyline([{46.0, 5.0}, {46.0, 72.0}])];
        create screen_decor with: [dtype: "title_left",
            label: "MẶT ĐỨNG SỐ HỌC (CLICK CHỌN TẦNG KHẢO SÁT)",
            location: {22.5, 6.5}];
        create screen_decor with: [dtype: "fig2_label", label: "North & South",   location: {13.5, 65.8}];
        create screen_decor with: [dtype: "fig2_label", label: "elevations",       location: {13.5, 67.5}];
        create screen_decor with: [dtype: "fig2_label", label: "East & West",     location: {31.5, 65.8}];
        create screen_decor with: [dtype: "fig2_label", label: "elevations",       location: {31.5, 67.5}];
        create screen_decor with: [dtype: "fig2_caption",
            label: "FIGURE 2   Numerical models of Cladding fire progression across 25 storeys",
            location: {6.5, 70.8}];
            
        write "=== KHỞI TẠO HOÀN TẤT: SẴN SÀNG MÔ PHỎNG ===";
    }

    // =========================================================================
    // XỬ LÝ CLICK CHUỘT
    //   Click vào mặt đứng bên trái (x: 4–44) → chọn tầng & đồng bộ trạng thái lửa
    //   Click vào mặt bằng bên phải (x: 49–93) → kích hoạt chuỗi phát hỏa (Sequence)
    // =========================================================================
    action handle_click {
        point pt <- #user_location;

        if (pt.x >= 4.0 and pt.x <= 44.0) {
            // 1. Lưu snapshot trạng thái lửa/khói của tầng hiện tại
            do save_current_floor_state;

            // 2. Chuyển tầng và vẽ lại kiến trúc sàn
            do select_floor;
            do rasterize_floor_plan;

            // 3. Phục hồi trạng thái lửa/khói riêng biệt của tầng mới chọn
            do restore_active_floor_state;
        } else if (pt.x >= 49.0 and pt.x <= 93.0 and pt.y >= 16.0 and pt.y <= 60.0) {
            // Click chọn điểm phát hỏa chính xác theo tọa độ chuột
            do place_fire_at_click;
        }
    }
}

// =============================================================================
// EXPERIMENT CHÍNH
// =============================================================================
experiment Grenfell_Modular_Simulation type: gui {

    action handle_click {
        ask simulation { do handle_click; }
    }

    output {
        display "Grenfell_Tower_Simulation" type: 2d background: rgb(245,248,252) {
            event #mouse_down action: handle_click;

            // 1. Khung trang trí tiêu đề & phân cách
            species screen_decor;

            // 2. Nửa bên trái: Mặt đứng 25 tầng tháp (Figure 2) - thể hiện Cladding 4 mặt E/N/S/W
            species floor_level_agt;

            // 3. Nửa bên phải: Mặt bằng kiến trúc 2D chi tiết
            species plan_element;
            species plan_label;

            // 4. Lớp Lửa & Khói (Grid Cell): chỉ hiển thị ô có lửa hoặc khói
            species grid_cell aspect: default;

            // 5. Trang trí La bàn & Khung nét đứt Limit of the model
            graphics "Decorations" {
                float px1 <- 49.0; float px2 <- 93.0;
                float py1 <- 16.0; float py2 <- 60.0;

                draw "North" at: {70.0, py1 - 1.2} color: rgb(20,30,60) font: font("Arial",14,#bold);
                draw "South" at: {70.0, py2 + 2.2} color: rgb(20,30,60) font: font("Arial",14,#bold);
                draw "West"  at: {px1 - 3.8, 38.5} color: rgb(20,30,60) font: font("Arial",14,#bold);
                draw "East"  at: {px2 + 1.2, 38.5} color: rgb(20,30,60) font: font("Arial",14,#bold);

                if (selected_floor = 4) {
                    float l_x1 <- 49.0 + (14.5 * 2.0);
                    float l_x2 <- px2;
                    float l_y1 <- py1 + 0.3;
                    float l_y2 <- py1 + (14.8 * 2.0);
                    loop i from: 0 to: 9 {
                        float bx <- l_x1 + (i * 1.5);
                        draw line([{bx, l_y1},{bx + 0.9, l_y1}]) color: #white;
                        draw line([{bx, l_y2},{bx + 0.9, l_y2}]) color: #white;
                    }
                    loop j from: 0 to: 18 {
                        float by <- l_y1 + (j * 1.5);
                        draw line([{l_x1, by},{l_x1, by + 0.9}]) color: #white;
                        draw line([{l_x2, by},{l_x2, by + 0.9}]) color: #white;
                    }
                    draw "Limit of the model" at: {l_x2 + 1.2, l_y2}
                        color: rgb(210,40,40) font: font("Arial",10,#bold);
                }
            }

            // 6. HUD trạng thái & Tiến trình lan truyền
            graphics "HUD_Status" {
                floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
                
                string phase_str <- (fire_phase = 0) ? "CHƯA BẮT ĐẦU (Click chuột vào sàn để đặt điểm cháy)" :
                    ((!cladding_ignited) ? "GIAI ĐOẠN 1: Lửa đang lan trong phòng (Chờ lan tới cửa sổ để bứt phá Cladding mặt ngoài...)" :
                    ((!crown_reached) ? ("GIAI ĐOẠN 2: Lửa Cladding mặt Đông đang bốc lên TẦNG " + highest_east_floor + "/24") :
                    ("GIAI ĐOẠN 3: Lan đỉnh Crown -> Chữ V ngược xuống mặt Bắc/Nam (Tầng " + v_lowest_floor + ") & mặt Tây")));

                string clad_status <- (cur_fl = nil) ? "" :
                    (" | Cladding Tầng " + selected_floor_name + ": "
                    + "Đông: " + ((cur_fl.clad_east > 1.5) ? "Than đen" : ((cur_fl.clad_east > 0.1) ? "CHÁY RỰC" : "An toàn"))
                    + " | Bắc: " + ((cur_fl.clad_north > 1.5) ? "Than đen" : ((cur_fl.clad_north > 0.1) ? "CHÁY RỰC" : "An toàn"))
                    + " | Nam: " + ((cur_fl.clad_south > 1.5) ? "Than đen" : ((cur_fl.clad_south > 0.1) ? "CHÁY RỰC" : "An toàn"))
                    + " | Tây: " + ((cur_fl.clad_west > 1.5) ? "Than đen" : ((cur_fl.clad_west > 0.1) ? "CHÁY RỰC" : "An toàn")));

                bool stair_smoky <- (cur_fl != nil and cur_fl.interior_smoke_depth >= 18.0);

                // Dòng 1: Tiến trình lan truyền Sequence
                draw "TIẾN TRÌNH: " + phase_str
                    at: {49.0, 63.8} color: (fire_started ? rgb(220,30,30) : rgb(30,120,40)) font: font("Arial",10,#bold);

                // Dòng 2: Trạng thái tầng đang xem & Buồng thang bộ
                draw "TẦNG " + selected_floor_name + clad_status
                    at: {49.0, 66.5} color: rgb(20,35,75) font: font("Arial",9,#bold);

                draw (stair_smoky ? "⚠️ THANG BỘ: NHIỄM KHÓI ĐỘC (NGUY HIỂM) | CỬA SỔ: " + ((cur_fl.window_broken) ? "VỠ / TÁP LỬA NỘI THẤT" : "BÌNH THƯỜNG") :
                                   "✅ THANG BỘ: THÔNG THOÁNG / AN TOÀN (Khói chưa lan tới sảnh)")
                    at: {49.0, 69.0} color: (stair_smoky ? rgb(200,30,0) : rgb(0,130,50)) font: font("Arial",9,#bold);

                // Dòng 3: Hướng dẫn người dùng
                draw "HƯỚNG DẪN: Click TRÁI vào cột Mặt đứng bên trái để chuyển tầng | Click chuột vào bất kỳ đâu trên mặt bằng để đặt mồi lửa"
                    at: {49.0, 71.5} color: rgb(50,60,80) font: font("Arial",8,#plain);
            }
        }
    }
}
