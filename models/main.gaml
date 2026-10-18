/**
 * Name: main.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: FILE ĐIỀU KHIỂN CHÍNH — Grenfell Tower Modular Simulation
 *
 *   Kiến trúc module:
 *     1_building_architecture.gaml  → Mặt đứng & Mặt bằng 2D
 *     2_grid_rasterizer.gaml        → Lớp lưới Grid Cell + ánh xạ cờ kiến trúc
 *     3_fire_cladding_dynamics.gaml → Động lực học Lửa & Khói
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
        write "=== KHỞI TẠO MÔ HÌNH GRENFELL TOWER (MODULAR) ===";

        // 1. Dựng bản vẽ kiến trúc (mặt đứng bên trái + mặt bằng bên phải)
        do build_tower_elevation;
        do build_active_floor_plan;

        // 2. Rasterize bản vẽ vector → Grid Cell flags
        do rasterize_floor_plan;

        // 3. Khởi tạo module sơ tán
        do init_evacuation_module;

        // 4. Trang trí giao diện (tiêu đề, phân cách, nhãn)
        create screen_decor with: [dtype: "header",
            label: "GRENFELL TOWER ARCHITECTURAL MODEL (PART 2 & PART 3 - WILEY/EFFECTIS)",
            location: {50.0, 3.2}];
        create screen_decor with: [dtype: "separator",
            shape: polyline([{46.0, 5.0}, {46.0, 72.0}])];
        create screen_decor with: [dtype: "title_left",
            label: "MẶT ĐỨNG SỐ HỌC (CLICK CHỌN TẦNG KHẢO SÁT)",
            location: {22.5, 6.5}];
        create screen_decor with: [dtype: "fig2_label", label: "North and South", location: {11.0, 65.8}];
        create screen_decor with: [dtype: "fig2_label", label: "elevations",       location: {12.2, 67.5}];
        create screen_decor with: [dtype: "fig2_label", label: "East and West",    location: {28.5, 65.8}];
        create screen_decor with: [dtype: "fig2_label", label: "elevations",       location: {29.8, 67.5}];
        create screen_decor with: [dtype: "fig2_caption",
            label: "FIGURE 2   Numerical models of the south/north and east/west faces of the Tower",
            location: {6.5, 70.8}];
            
        write "=== KHỞI TẠO HOÀN TẤT: SẴN SÀNG HIỂN THỊ ===";
    }

    // =========================================================================
    // XỬ LÝ CLICK CHUỘT
    //   Click vào mặt đứng bên trái (x: 4–44) → chọn tầng
    //   Click vào mặt bằng bên phải (x: 49–93) → đặt điểm cháy
    // =========================================================================
    action handle_click {
        point pt <- #user_location;

        if (pt.x >= 4.0 and pt.x <= 44.0) {
            do select_floor;
            // Sau khi chuyển tầng, rasterize lại các cờ trên grid
            do rasterize_floor_plan;
        } else if (pt.x >= 49.0 and pt.x <= 93.0 and pt.y >= 16.0 and pt.y <= 60.0) {
            if (!fire_started) {
                do place_fire_at_click;
            }
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

            // 2. Nửa bên trái: Mặt đứng 25 tầng tháp (Figure 2)
            species floor_level_agt;

            // 3. Nửa bên phải: Mặt bằng kiến trúc 2D chi tiết
            species plan_element;
            species plan_label;

            // 4. Lớp Lửa & Khói (Grid Cell): CHỈ vẽ các ô có lửa hoặc khói
            // Không dùng câu lệnh `grid` thô để tránh phủ lưới kín màn hình
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

            // 6. HUD trạng thái & Hướng dẫn sử dụng
            graphics "HUD_Status" {
                draw "TANG: " + selected_floor_name
                    + " | LUA: " + (fire_started ? "DANG CHAY" : "Chua bat dau (Click mat bang de dat diem chay)")
                    + " | O chay: " + length(grid_cell where each.burning)
                    + " | O khoi: " + length(grid_cell where each.smoky)
                    at: {49.0, 64.0} color: rgb(180,30,30) font: font("Arial",10,#bold);

                draw "BAN VE KIEN TRUC: 22m x 22m | LOI KY THUAT: 8m x 8m | Nen phong: MAU TRANG"
                    at: {49.0, 67.0} color: rgb(20,35,75) font: font("Arial",9,#bold);

                draw "HUONG DAN: Click TRAI vao mat dung de chon tang | Click vao mat bang de dat diem chay"
                    at: {49.0, 70.0} color: rgb(40,50,70) font: font("Arial",9,#plain);
            }
        }
    }
}
