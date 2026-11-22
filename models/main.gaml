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
    bool is_test_mode <- false;

    init {
        write "=== KHỞI TẠO MÔ HÌNH GRENFELL TOWER (MODULAR DUAL-LAYER) ===";
        v_lowest_floor <- test_max_floor;

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
            int prev_floor <- selected_floor;
            // 1. Lưu snapshot trạng thái lửa/khói của tầng hiện tại
            do save_current_floor_state;

            // 2. Chuyển tầng (chỉ vẽ lại vector nếu đổi giữa Tầng Trệt và Tầng Điển Hình)
            do select_floor;

            bool prev_is_ground <- (prev_floor = 0);
            bool curr_is_ground <- (selected_floor = 0);
            if (prev_is_ground != curr_is_ground) {
                do rasterize_floor_plan;
            }

            // 3. Phục hồi trạng thái lửa/khói riêng biệt của tầng mới chọn tức thời (0 delay)
            if (selected_floor != prev_floor) {
                do restore_active_floor_state;
            }
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
    parameter "Giới hạn số tầng mô phỏng" var: test_max_floor category: "Cấu hình Tòa Nhà" min: 4 max: 24 step: 1;
    parameter "Mô phỏng Dân số Toàn tháp" var: full_tower_population category: "Cấu hình Sơ Tán";

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

            // 4. Lớp Lửa & Khói
            species grid_cell aspect: default;

            // 5. Cửa buồng thang thoát hiểm SFPE (FIFO Bottleneck)
            species stair_door;

            // 6. Quần thể Cư dân (Tác tử người Occupant với hiển thị 2 chiều Sức khỏe - Hoảng sợ)
            species occupant aspect: default;

            // 7. Trang trí La bàn & Khung nét đứt Limit of the model
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
                        draw line([{bx, l_y1},{bx + 0.9, l_y1}]) color: rgb(210,40,40);
                        draw line([{bx, l_y2},{bx + 0.9, l_y2}]) color: rgb(210,40,40);
                    }
                    loop j from: 0 to: 18 {
                        float by <- l_y1 + (j * 1.5);
                        draw line([{l_x1, by},{l_x1, by + 0.9}]) color: rgb(210,40,40);
                        draw line([{l_x2, by},{l_x2, by + 0.9}]) color: rgb(210,40,40);
                    }
                    draw "Limit of the model" at: {l_x2 + 1.2, l_y2}
                        color: rgb(210,40,40) font: font("Arial",10,#bold);
                }
            }

            graphics "HUD_Status" {
                floor_level_agt cur_fl <- floor_map contains_key selected_floor ? floor_map[selected_floor] : nil;
                string phase_str <- (fire_phase = 0) ? "Chưa bắt đầu" :
                    ((!cladding_ignited) ? "Lửa lan trong phòng" :
                    ((!crown_reached) ? ("Cladding mặt Đông: tầng " + highest_east_floor + "/" + test_max_floor) :
                    ("Lửa lan xuống từ đỉnh: tầng " + v_lowest_floor)));
                bool stair_smoky <- !empty(active_smoky_cells where (each.is_stairwell));
                string clad_status <- (cur_fl = nil) ? "" :
                    ("Đông: " + ((cur_fl.clad_east > 1.5) ? "Cháy hết" : ((cur_fl.clad_east > 0.1) ? "Đang cháy" : "Chưa cháy"))
                    + " | Bắc: " + ((cur_fl.clad_north > 1.5) ? "Cháy hết" : ((cur_fl.clad_north > 0.1) ? "Đang cháy" : "Chưa cháy"))
                    + " | Nam: " + ((cur_fl.clad_south > 1.5) ? "Cháy hết" : ((cur_fl.clad_south > 0.1) ? "Đang cháy" : "Chưa cháy"))
                    + " | Tây: " + ((cur_fl.clad_west > 1.5) ? "Cháy hết" : ((cur_fl.clad_west > 0.1) ? "Đang cháy" : "Chưa cháy")));

                draw "TIẾN TRÌNH LỬA: " + phase_str at: {49.0, 61.8}
                    color: (fire_started ? rgb(220,30,30) : rgb(30,120,40)) font: font("Arial",9,#bold);
                draw ("CLADDING " + selected_floor_name + ": " + clad_status) at: {49.0, 63.8}
                    color: rgb(20,35,75) font: font("Arial",8,#bold);
                draw (stair_smoky ? "THANG BỘ: CÓ KHÓI" : "THANG BỘ: CHƯA CÓ KHÓI") at: {49.0, 65.6}
                    color: (stair_smoky ? rgb(200,30,0) : rgb(0,130,50)) font: font("Arial",8,#bold);
                draw "SỨC KHỎE: Xanh >85% | Vàng >60% | Cam >30% | Đỏ ≤30% | X: mất khả năng di chuyển"
                    at: {49.0, 67.4} color: rgb(50,70,95) font: font("Arial",8,#plain);
                draw "Vòng tím: hoảng loạn | Viền đôi: người già | Click mặt đứng: chọn tầng | Click mặt bằng: đặt lửa"
                    at: {49.0, 69.2} color: rgb(50,70,95) font: font("Arial",8,#plain);
            }

        }
        
        // Count states directly so charts do not lag behind the HUD's periodic statistics.
            display "Hanh_vi_so_tan" {
                chart "Trang thai hanh vi theo chu ky" type: series {
                    data "Chua phan ung" value: length(occupant where (each.behavior_state = "stay_in_flat")) color: #gray;
                    data "Dang chuan bi" value: length(occupant where (each.behavior_state = "preparing_evacuation")) color: #orange;
                    data "Dang di chuyen" value: length(occupant where (each.behavior_state = "evacuating" or each.behavior_state = "retreating_upward")) color: #blue;
                    data "Dang cho" value: length(occupant where (each.behavior_state = "waiting_at_door")) color: #yellow;
                    data "Tru an" value: length(occupant where (each.behavior_state = "sheltering")) color: #magenta;
                }
            }

            display "Ket_qua_so_tan" {
                chart "Ket qua so tan theo chu ky" type: series {
                    data "Da thoat" value: length(occupant where (each.behavior_state = "evacuated")) color: #green;
                    data "Con trong toa" value: length(occupant where (each.behavior_state != "evacuated")) color: #blue;
                    data "Mat kha nang di chuyen" value: length(occupant where (each.is_incapacitated)) color: #red;
                }
            }
    }
}

