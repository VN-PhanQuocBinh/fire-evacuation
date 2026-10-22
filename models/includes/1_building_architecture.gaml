/**
 * Module: 1_building_architecture.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: BẢN VẼ KIẾN TRÚC 2D — MẶT ĐỨNG & MẶT BẰNG GRENFELL TOWER
 *   - Toàn bộ agent species, global helpers, actions vẽ mặt đứng & mặt bằng
 *   - Màu nền mỗi căn hộ: TRẮNG (thay vì màu riêng từng căn)
 *   - Tương thích GAMA 2025.6.4
 */

model building_architecture

global {
    // -------------------------------------------------------------------------
    // 1. KHÔNG GIAN MÔI TRƯỜNG TOÀN CỤC (GLOBAL SHAPE: 100 x 75)
    // -------------------------------------------------------------------------
    geometry shape <- rectangle(100.0, 75.0) at_location {50.0, 37.5};

    int    selected_floor      <- 4;
    string selected_floor_name <- "4th (Flat 16)";

    // Tọa độ & kích thước mặt bằng 2D bên phải (44.0 = 22.0m × 2.0 px/m)
    float px_origin  <- 49.0;
    float py_origin  <- 16.0;
    float floor_dim  <- 44.0;

    // ------------------------------------------------------------------
    // Utility: chuyển toạ độ mặt bằng (m) → toạ độ màn hình
    // ------------------------------------------------------------------
    float to_px(float lx) { return px_origin + (lx * 2.0); }
    float to_py(float ly) { return py_origin + (ly * 2.0); }

    // Tạo hình chữ nhật từ 2 điểm góc đối diện
    geometry create_box(float x1, float y1, float x2, float y2) {
        float min_x <- min(x1, x2);
        float max_x <- max(x1, x2);
        float min_y <- min(y1, y2);
        float max_y <- max(y1, y2);
        float w <- max_x - min_x;
        float h <- max_y - min_y;
        return rectangle(w, h) at_location {min_x + w / 2.0, min_y + h / 2.0};
    }

    // Tạo hình bát giác (cột bê tông)
    geometry create_column_geom(float cx, float cy, float r) {
        return polygon([
            {cx + r,             cy},
            {cx + r * 0.7071, cy + r * 0.7071},
            {cx,             cy + r},
            {cx - r * 0.7071, cy + r * 0.7071},
            {cx - r,             cy},
            {cx - r * 0.7071, cy - r * 0.7071},
            {cx,             cy - r},
            {cx + r * 0.7071, cy - r * 0.7071}
        ]);
    }

    // Hàm đối xứng qua tâm {11, 11}
    float sym_x(float x, bool mir_x) { return mir_x ? (22.0 - x) : x; }
    float sym_y(float y, bool mir_y) { return mir_y ? (22.0 - y) : y; }

    // Tạo plan_element có hỗ trợ gương
    action add_plan_sym(string et, string el, rgb ec,
                        float x1, float y1, float x2, float y2,
                        bool mx, bool my) {
        float nx1 <- sym_x(x1, mx); float nx2 <- sym_x(x2, mx);
        float ny1 <- sym_y(y1, my); float ny2 <- sym_y(y2, my);
        create plan_element with: [
            etype:  et,
            elabel: el,
            ecolor: ec,
            shape:  create_box(to_px(min(nx1,nx2)), to_py(min(ny1,ny2)),
                               to_px(max(nx1,nx2)), to_py(max(ny1,ny2)))
        ];
    }

    // =========================================================================
    // 2. KHỞI TẠO — được gọi từ main.gaml, không init trực tiếp ở đây
    // =========================================================================

    // =========================================================================
    // A. MẶT ĐỨNG 25 TẦNG (FIGURE 2)
    // =========================================================================
    action build_tower_elevation {
        list<string> f_names <- [
            "Ground","Mezzanine","Walkway","Office",
            "4th (Flat 16)","5th","6th","7th","8th","9th","10th",
            "11th","12th","13th","14th","15th","16th","17th","18th","19th","20th",
            "21st","22nd","23th","Roof"
        ];
        float base_y <- 63.5;
        float f_step <- 2.12;
        loop i from: 0 to: 24 {
            float y_b <- base_y - (i * f_step);
            float y_t <- y_b - f_step;
            float y_m <- (y_t + y_b) / 2.0;
            create floor_level_agt with: [
                floor_id:    i,
                floor_label: f_names[i],
                is_selected: (i = selected_floor),
                y_top: y_t, y_bot: y_b, y_mid: y_m,
                shape: create_box(4.0, y_t, 44.0, y_b)
            ];
        }
    }

    // =========================================================================
    // B. MẶT BẰNG 2D CHI TIẾT TẦNG ĐANG CHỌN (BÊN PHẢI)
    //    Màu nền tất cả căn hộ: TRẮNG
    // =========================================================================
    action build_active_floor_plan {
        ask plan_element { do die; }
        ask plan_label   { do die; }

        float px1 <- px_origin;
        float px2 <- px_origin + floor_dim;
        float py1 <- py_origin;
        float py2 <- py_origin + floor_dim;

        string p_title <- (selected_floor = 4) ?
            "MẶT BẰNG TẦNG 4: CHI TIẾT ĐẦY ĐỦ FLAT 16 & CÁC CĂN HỘ" :
            ((selected_floor = 0) ? "MẶT BẰNG TẦNG TRỆT (GROUND FLOOR LOBBY)" :
            ("MẶT BẰNG TẦNG " + selected_floor_name + " (TYPICAL RESIDENTIAL FLOOR)"));

        string p_sub <- (selected_floor = 4) ?
            "Sàn 22m x 22m: Flat 16 có đầy đủ nội thất & Tủ lạnh phát hỏa (ORIGIN), 5 căn hộ còn lại thể hiện rõ ràng cấu trúc phân phòng" :
            ((selected_floor = 0) ? "Lối vào chính, Sảnh chung, Phòng trẻ em Nursery, Văn phòng Office, Trạm biến áp & Lõi thang" :
            "Sàn điển hình 22m x 22m: 6 Căn hộ phân chia phòng chuẩn xác, Lõi trung tâm 8m x 8m (2 Thang máy, Thang bộ thoát hiểm)");

        create plan_label with: [m_text: p_title, s_text: p_sub, location: {71.0, 11.5}];

        if (selected_floor = 0) {
            do build_ground_floor;
        } else {
            do build_residential_floor;
        }

        // 14 Cột bê tông bát giác
        list<point> col_positions <- [
            {0.5,0.5},{5.75,0.5},{11.0,0.5},{16.25,0.5},{21.5,0.5},
            {21.5,7.0},{21.5,15.0},
            {21.5,21.5},{16.25,21.5},{11.0,21.5},{5.75,21.5},{0.5,21.5},
            {0.5,15.0},{0.5,7.0}
        ];
        loop cp over: col_positions {
            create plan_element with: [
                etype: "column", elabel: "", ecolor: rgb(110,120,130),
                shape: create_column_geom(to_px(cp.x), to_py(cp.y), 0.8)
            ];
        }

        // Tường bao viền ngoài
        create plan_element with: [etype:"outer_wall",elabel:"",ecolor:#black,shape: create_box(px1,      py1-0.3, px2,      py1)];
        create plan_element with: [etype:"outer_wall",elabel:"",ecolor:#black,shape: create_box(px2,      py1,     px2+0.3, py2)];
        create plan_element with: [etype:"outer_wall",elabel:"",ecolor:#black,shape: create_box(px1,      py2,     px2,     py2+0.3)];
        create plan_element with: [etype:"outer_wall",elabel:"",ecolor:#black,shape: create_box(px1-0.3, py1,     px1,     py2)];
    }

    // -------------------------------------------------------------------------
    // B.1 TẦNG TRỆT (GROUND FLOOR)
    // -------------------------------------------------------------------------
    action build_ground_floor {
        // Lõi trung tâm
        create plan_element with: [etype:"lobby",elabel:"SẢNH ĐỆM THANG",ecolor:rgb(215,222,230),shape:create_box(to_px(9.4),to_py(7.0),to_px(12.6),to_py(15.0))];
        // Thang máy
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(6.9),to_py(8.4),to_px(9.4),to_py(8.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(6.9),to_py(13.4),to_px(9.4),to_py(13.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(6.9),to_py(8.4),to_px(7.1),to_py(13.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(7.0),to_py(10.9),to_px(9.4),to_py(11.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(9.2),to_py(8.4),to_px(9.4),to_py(9.3))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(9.2),to_py(10.3),to_px(9.4),to_py(11.7))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(9.2),to_py(12.7),to_px(9.4),to_py(13.6))];
        create plan_element with: [etype:"lift_cab",elabel:"LIFT 1",ecolor:rgb(255,215,50),shape:create_box(to_px(7.1),to_py(8.6),to_px(9.2),to_py(10.9))];
        create plan_element with: [etype:"lift_cab",elabel:"LIFT 2",ecolor:rgb(255,215,50),shape:create_box(to_px(7.1),to_py(11.1),to_px(9.2),to_py(13.4))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(9.2),to_py(9.3),to_px(9.45),to_py(10.3))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(9.2),to_py(11.7),to_px(9.45),to_py(12.7))];
        // Thang bộ
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(12.6),to_py(8.4),to_px(15.1),to_py(8.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(12.6),to_py(13.4),to_px(15.1),to_py(13.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(14.9),to_py(8.4),to_px(15.1),to_py(13.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(12.6),to_py(8.4),to_px(12.8),to_py(10.55))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(12.6),to_py(11.45),to_px(12.8),to_py(13.6))];
        create plan_element with: [etype:"stair_box",elabel:"THANG BỘ",ecolor:#white,shape:create_box(to_px(12.8),to_py(8.6),to_px(14.9),to_py(13.4))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(180,50,50),shape:create_box(to_px(12.6),to_py(10.55),to_px(12.85),to_py(11.45))];
        // Riser
        create plan_element with: [etype:"riser",elabel:"RISER",ecolor:rgb(150,155,165),shape:create_box(to_px(7.0),to_py(7.0),to_px(8.5),to_py(8.4))];
        create plan_element with: [etype:"riser",elabel:"RISER",ecolor:rgb(150,155,165),shape:create_box(to_px(7.0),to_py(13.6),to_px(8.5),to_py(15.0))];
        create plan_element with: [etype:"riser",elabel:"CHÂN ỐNG RÁC",ecolor:rgb(150,155,165),shape:create_box(to_px(13.5),to_py(7.0),to_px(15.0),to_py(8.4))];
        create plan_element with: [etype:"riser",elabel:"RISER",ecolor:rgb(150,155,165),shape:create_box(to_px(13.5),to_py(13.6),to_px(15.0),to_py(15.0))];

        // Khu Nhà trẻ (trắng)
        create plan_element with: [etype:"room",elabel:"P.SINH HOẠT TRẺ",ecolor:#white,shape:create_box(to_px(0.0),to_py(0.0),to_px(10.9),to_py(7.0))];
        create plan_element with: [etype:"room",elabel:"P.NGHỈ TRẺ",ecolor:#white,shape:create_box(to_px(10.9),to_py(0.0),to_px(16.5),to_py(7.0))];
        create plan_element with: [etype:"room",elabel:"WC TRẺ EM",ecolor:#white,shape:create_box(to_px(0.0),to_py(7.0),to_px(5.5),to_py(11.0))];
        create plan_element with: [etype:"room",elabel:"BẾP NHÀ TRẺ",ecolor:#white,shape:create_box(to_px(0.0),to_py(11.0),to_px(5.5),to_py(15.0))];
        create plan_element with: [etype:"room",elabel:"LỐI VÀO",ecolor:#white,shape:create_box(to_px(5.5),to_py(7.0),to_px(7.0),to_py(15.0))];
        create plan_element with: [etype:"flat_tag",elabel:"NHÀ TRẺ GRENFELL (NURSERY)",ecolor:rgb(15,35,90),shape:create_box(to_px(2.0),to_py(1.2),to_px(9.0),to_py(1.6))];
        // Tường nhà trẻ
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(10.8),to_py(0.0),to_px(11.0),to_py(7.0))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(0.0),to_py(6.9),to_px(7.0),to_py(7.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(0.0),to_py(10.9),to_px(5.5),to_py(11.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(0.0),to_py(14.9),to_px(7.0),to_py(15.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(5.4),to_py(7.0),to_px(5.6),to_py(15.0))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(6.9),to_py(7.0),to_px(7.1),to_py(8.4))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(6.9),to_py(13.6),to_px(7.1),to_py(15.0))];
        // Cửa nhà trẻ
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(5.8),to_py(6.9),to_px(6.7),to_py(7.1))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(5.4),to_py(8.5),to_px(5.6),to_py(9.5))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(5.4),to_py(12.5),to_px(5.6),to_py(13.5))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(10.8),to_py(2.5),to_px(11.0),to_py(4.0))];
        create plan_element with: [etype:"door",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(0.0),to_py(8.5),to_px(0.3),to_py(10.0))];
        // Cửa sổ nhà trẻ
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(2.0),to_py(-0.06),to_px(4.5),to_py(0.06))];
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(6.5),to_py(-0.06),to_px(9.0),to_py(0.06))];
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(12.5),to_py(-0.06),to_px(15.0),to_py(0.06))];
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(-0.06),to_py(2.0),to_px(0.06),to_py(5.0))];

        // Văn phòng quản lý (trắng)
        create plan_element with: [etype:"room",elabel:"VP QUẢN LÝ",ecolor:#white,shape:create_box(to_px(0.0),to_py(15.0),to_px(5.5),to_py(19.0))];
        create plan_element with: [etype:"room",elabel:"P.HỌP & HỒ SƠ",ecolor:#white,shape:create_box(to_px(0.0),to_py(19.0),to_px(5.5),to_py(22.0))];
        create plan_element with: [etype:"room",elabel:"WC & KHO NV",ecolor:#white,shape:create_box(to_px(5.5),to_py(15.0),to_px(8.0),to_py(22.0))];
        create plan_element with: [etype:"flat_tag",elabel:"BAN QUẢN LÝ (ESTATE OFFICE)",ecolor:rgb(15,35,90),shape:create_box(to_px(0.5),to_py(15.6),to_px(7.5),to_py(16.0))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(0.0),to_py(18.9),to_px(5.5),to_py(19.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(5.4),to_py(15.0),to_px(5.6),to_py(22.0))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(7.9),to_py(15.0),to_px(8.1),to_py(22.0))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(7.9),to_py(16.5),to_px(8.1),to_py(17.8))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(5.4),to_py(17.0),to_px(5.6),to_py(18.2))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(5.4),to_py(19.8),to_px(5.6),to_py(21.0))];
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(-0.06),to_py(16.5),to_px(0.06),to_py(18.5))];
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(-0.06),to_py(19.5),to_px(0.06),to_py(21.5))];
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(1.5),to_py(21.94),to_px(4.0),to_py(22.06))];

        // Sảnh đón tiếp chính
        create plan_element with: [etype:"lobby",elabel:"SẢNH ĐÓN TIẾP CHÍNH",ecolor:rgb(220,228,238),shape:create_box(to_px(8.0),to_py(15.0),to_px(12.6),to_py(22.0))];
        create plan_element with: [etype:"lobby",elabel:"",ecolor:rgb(220,228,238),shape:create_box(to_px(12.6),to_py(15.0),to_px(15.0),to_py(22.0))];
        create plan_element with: [etype:"furniture",elabel:"LỄ TÂN / BẢO VỆ",ecolor:rgb(180,130,80),shape:create_box(to_px(12.8),to_py(17.0),to_px(14.7),to_py(19.0))];
        create plan_element with: [etype:"door",elabel:"CỬA CHÍNH",ecolor:#gold,shape:create_box(to_px(9.5),to_py(21.85),to_px(12.5),to_py(22.15))];
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(8.2),to_py(21.94),to_px(9.3),to_py(22.06))];
        create plan_element with: [etype:"facade_window",elabel:"",ecolor:#deepskyblue,shape:create_box(to_px(12.7),to_py(21.94),to_px(14.8),to_py(22.06))];

        // Khu kỹ thuật (trắng)
        create plan_element with: [etype:"room",elabel:"TRẠM BIẾN ÁP (SUBSTATION)",ecolor:#white,shape:create_box(to_px(16.5),to_py(0.0),to_px(22.0),to_py(7.0))];
        create plan_element with: [etype:"room",elabel:"P.RÁC TRUNG TÂM",ecolor:#white,shape:create_box(to_px(15.0),to_py(7.0),to_px(22.0),to_py(12.8))];
        create plan_element with: [etype:"lobby",elabel:"LỐI THOÁT HIỂM",ecolor:rgb(250,230,230),shape:create_box(to_px(15.0),to_py(12.8),to_px(22.0),to_py(16.5))];
        create plan_element with: [etype:"room",elabel:"P.BƠM",ecolor:#white,shape:create_box(to_px(15.0),to_py(16.5),to_px(22.0),to_py(22.0))];
        create plan_element with: [etype:"flat_tag",elabel:"KHU KỸ THUẬT & TRẠM BIẾN ÁP",ecolor:rgb(15,35,90),shape:create_box(to_px(16.8),to_py(1.2),to_px(21.5),to_py(1.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(16.4),to_py(0.0),to_px(16.6),to_py(7.0))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(15.0),to_py(6.9),to_px(22.0),to_py(7.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(15.0),to_py(12.7),to_px(22.0),to_py(12.9))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(15.0),to_py(16.4),to_px(22.0),to_py(16.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(14.9),to_py(15.0),to_px(15.1),to_py(22.0))];
        create plan_element with: [etype:"door",elabel:"CỬA THOÁT HIỂM",ecolor:rgb(220,40,40),shape:create_box(to_px(21.85),to_py(13.8),to_px(22.15),to_py(15.5))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(120,130,140),shape:create_box(to_px(21.85),to_py(8.5),to_px(22.15),to_py(11.0))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(120,130,140),shape:create_box(to_px(21.85),to_py(2.5),to_px(22.15),to_py(4.5))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(120,130,140),shape:create_box(to_px(21.85),to_py(18.0),to_px(22.15),to_py(19.5))];
    }

    // -------------------------------------------------------------------------
    // B.2 TẦNG CĂN HỘ (Tầng 1–24, mặc định Tầng 4)
    //     Màu nền phòng: TRẮNG
    // -------------------------------------------------------------------------
    action build_residential_floor {
        // Lõi trung tâm
        create plan_element with: [etype:"lobby",elabel:"SẢNH TẦNG",ecolor:rgb(215,222,230),shape:create_box(to_px(9.4),to_py(7.0),to_px(12.6),to_py(15.0))];
        create plan_element with: [etype:"lobby",elabel:"",ecolor:rgb(215,222,230),shape:create_box(to_px(7.0),to_py(7.0),to_px(15.0),to_py(8.4))];
        create plan_element with: [etype:"lobby",elabel:"",ecolor:rgb(215,222,230),shape:create_box(to_px(8.5),to_py(13.6),to_px(13.5),to_py(15.0))];
        // Thang máy
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(6.9),to_py(8.4),to_px(9.4),to_py(8.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(6.9),to_py(13.4),to_px(9.4),to_py(13.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(6.9),to_py(8.4),to_px(7.1),to_py(13.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(7.0),to_py(10.9),to_px(9.4),to_py(11.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(9.2),to_py(8.4),to_px(9.4),to_py(9.3))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(9.2),to_py(10.3),to_px(9.4),to_py(11.7))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(9.2),to_py(12.7),to_px(9.4),to_py(13.6))];
        create plan_element with: [etype:"lift_cab",elabel:"LIFT 1",ecolor:rgb(255,215,50),shape:create_box(to_px(7.1),to_py(8.6),to_px(9.2),to_py(10.9))];
        create plan_element with: [etype:"lift_cab",elabel:"LIFT 2",ecolor:rgb(255,215,50),shape:create_box(to_px(7.1),to_py(11.1),to_px(9.2),to_py(13.4))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(9.2),to_py(9.3),to_px(9.45),to_py(10.3))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(205,133,63),shape:create_box(to_px(9.2),to_py(11.7),to_px(9.45),to_py(12.7))];
        // Thang bộ
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(12.6),to_py(8.4),to_px(15.1),to_py(8.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(12.6),to_py(13.4),to_px(15.1),to_py(13.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(14.9),to_py(8.4),to_px(15.1),to_py(13.6))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(12.6),to_py(8.4),to_px(12.8),to_py(10.55))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:rgb(54,69,79),shape:create_box(to_px(12.6),to_py(11.45),to_px(12.8),to_py(13.6))];
        create plan_element with: [etype:"stair_box",elabel:"THANG BỘ",ecolor:#white,shape:create_box(to_px(12.8),to_py(8.6),to_px(14.9),to_py(13.4))];
        create plan_element with: [etype:"door",elabel:"",ecolor:rgb(180,50,50),shape:create_box(to_px(12.6),to_py(10.55),to_px(12.85),to_py(11.45))];
        // Riser
        create plan_element with: [etype:"riser",elabel:"RISER",ecolor:rgb(150,155,165),shape:create_box(to_px(7.0),to_py(13.6),to_px(8.5),to_py(15.0))];
        create plan_element with: [etype:"riser",elabel:"ỐNG RÁC",ecolor:rgb(150,155,165),shape:create_box(to_px(13.2),to_py(7.0),to_px(14.4),to_py(7.7))];
        create plan_element with: [etype:"riser",elabel:"RISER",ecolor:rgb(150,155,165),shape:create_box(to_px(13.5),to_py(13.6),to_px(15.0),to_py(15.0))];

        // 4 CĂN GÓC (2-Bedroom) — MÀU NỀN TRẮNG
        list<point> c_mirs <- [{0.0,0.0},{1.0,0.0},{0.0,1.0},{1.0,1.0}];
        int base_num <- (selected_floor - 3) * 10;
        list<string> c_titles <- (selected_floor = 4) ?
            ["FLAT 16 [NE - ĐIỂM CHÁY]","FLAT 15 [NW - 2PN]","FLAT 12 [SE - 2PN]","FLAT 13 [SW - 2PN]"] :
            ["FLAT "+(base_num+6)+" [NE - 2PN]","FLAT "+(base_num+5)+" [NW - 2PN]",
             "FLAT "+(base_num+2)+" [SE - 2PN]","FLAT "+(base_num+3)+" [SW - 2PN]"];

        loop idx from: 0 to: 3 {
            point mir <- c_mirs[idx];
            bool mx   <- (mir.x = 1.0);
            bool my   <- (mir.y = 1.0);
            string fname  <- c_titles[idx];
            bool is_f16   <- (selected_floor = 4 and idx = 0);

            // Phòng — màu TRẮNG
            do add_plan_sym("room", is_f16?"Khách":"P.KHÁCH", #white, 16.25,0.0,22.0,4.6, mx,my);
            do add_plan_sym("room", is_f16?"Bếp (Origin)":"P.BẾP",    #white, 16.25,4.6,22.0,7.0, mx,my);
            do add_plan_sym("room", "P.NGỦ 1",  #white, 11.0,0.0,13.62,3.4, mx,my);
            do add_plan_sym("room", "P.NGỦ 2",  #white, 13.62,0.0,16.25,3.4, mx,my);
            do add_plan_sym("room", "",              #white, 11.0,3.4,16.25,4.6, mx,my);
            do add_plan_sym("room", "SẢNH",         #white, 11.0,4.6,13.62,7.0, mx,my);
            do add_plan_sym("room", "TẮM & WC",     #white, 13.62,4.6,16.25,7.0, mx,my);

            // Thẻ định danh
            create plan_element with: [
                etype: "flat_tag", elabel: fname, ecolor: #yellow,
                shape: create_box(to_px(sym_x(18.0,mx)),to_py(sym_y(0.5,my)),
                                  to_px(sym_x(20.5,mx)),to_py(sym_y(0.9,my)))
            ];

            // Tường & Cửa
            do add_plan_sym("wall","",rgb(54,69,79), 16.15,0.0,16.35,3.4, mx,my);
            do add_plan_sym("door","",rgb(205,133,63), 16.5,4.5,17.5,4.7, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 17.5,4.5,18.5,4.7, mx,my);
            do add_plan_sym("door","",rgb(205,133,63), 18.5,4.5,20.0,4.7, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 20.0,4.5,22.0,4.7, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 16.15,4.6,16.35,7.0, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 11.0,3.3,11.8,3.5, mx,my);
            do add_plan_sym("door","",rgb(205,133,63), 11.8,3.3,12.7,3.5, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 12.7,3.3,14.3,3.5, mx,my);
            do add_plan_sym("door","",rgb(205,133,63), 14.3,3.3,15.2,3.5, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 15.2,3.3,16.25,3.5, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 13.52,0.0,13.72,3.4, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 13.52,4.6,13.72,7.0, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 13.62,4.5,14.3,4.7, mx,my);
            do add_plan_sym("door","",rgb(205,133,63), 14.3,4.5,15.2,4.7, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 15.2,4.5,16.25,4.7, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 11.0,6.9,11.6,7.1, mx,my);
            do add_plan_sym("door","",rgb(205,133,63), 11.6,6.9,12.5,7.1, mx,my);
            do add_plan_sym("wall","",rgb(54,69,79), 12.5,6.9,16.25,7.1, mx,my);
            // Cửa sổ
            do add_plan_sym("facade_window","",#deepskyblue, 11.8,-0.06,13.0,0.06, mx,my);
            do add_plan_sym("facade_window","",#deepskyblue, 14.2,-0.06,15.4,0.06, mx,my);
            do add_plan_sym("facade_window","",#deepskyblue, 17.2,-0.06,19.0,0.06, mx,my);
            do add_plan_sym("facade_window","",#deepskyblue, 21.94,1.4,22.06,3.4, mx,my);
            do add_plan_sym("facade_window","",#deepskyblue, 21.94,5.2,22.06,6.6, mx,my);

            // Nội thất Flat 16 (ORIGIN)
            if (is_f16) {
                do add_plan_sym("origin_fridge","ORIGIN",#red, 21.2,6.2,21.9,6.9, mx,my);
                do add_plan_sym("furniture","Máy Giặt",#silver, 20.3,6.3,21.0,6.9, mx,my);
                do add_plan_sym("furniture","Bếp Nấu",#darkblue, 19.4,6.3,20.1,6.9, mx,my);
                do add_plan_sym("furniture","Bồn Rửa",#saddlebrown, 16.8,6.3,19.2,6.9, mx,my);
                do add_plan_sym("furniture","Mini-fridge",#lightcyan, 21.2,4.8,21.9,5.4, mx,my);
                do add_plan_sym("furniture","Sofa",#white, 17.5,0.4,20.2,1.2, mx,my);
                do add_plan_sym("furniture","Sofa",#white, 20.6,1.4,21.4,3.4, mx,my);
                do add_plan_sym("furniture","Thảm",rgb(45,95,175), 17.8,1.4,20.2,3.4, mx,my);
                do add_plan_sym("furniture","Bàn Trà",#cyan, 18.3,1.8,19.7,2.9, mx,my);
                do add_plan_sym("furniture","Bàn Ăn",#teal, 16.5,2.2,17.5,3.6, mx,my);
                do add_plan_sym("furniture","TV",#black, 16.35,0.6,16.85,1.8, mx,my);
                do add_plan_sym("furniture","Giường 1",rgb(240,246,255), 11.3,0.8,13.1,2.8, mx,my);
                do add_plan_sym("furniture","Tủ Áo 1",#saddlebrown, 13.2,0.6,13.55,2.6, mx,my);
                do add_plan_sym("furniture","Giường 2",rgb(240,246,255), 13.9,0.8,15.7,2.8, mx,my);
                do add_plan_sym("furniture","Tủ Áo 2",#saddlebrown, 15.8,0.6,16.15,2.6, mx,my);
                do add_plan_sym("furniture","Bồn Tắm",#white, 14.0,5.0,16.0,5.7, mx,my);
                do add_plan_sym("furniture","Bồn Cầu",#white, 15.2,6.2,16.0,6.8, mx,my);
                do add_plan_sym("furniture","Lavabo",#white, 14.0,6.2,14.8,6.8, mx,my);
            }
        }

        // 2 CĂN GIỮA (1-Bedroom: Flat 11 & Flat 14) — MÀU NỀN TRẮNG
        list<bool> mid_mirs <- [false, true];
        list<string> mid_titles <- (selected_floor = 4) ?
            ["FLAT 11 [MẶT ĐÔNG - 1PN]","FLAT 14 [MẶT TÂY - 1PN]"] :
            ["FLAT "+(base_num+1)+" [MẶT ĐÔNG - 1PN]","FLAT "+(base_num+4)+" [MẶT TÂY - 1PN]"];

        loop mi from: 0 to: 1 {
            bool mx_m  <- mid_mirs[mi];
            string m_code <- mid_titles[mi];

            do add_plan_sym("room","P.KHÁCH",#white, 17.5,7.0,22.0,10.4, mx_m,false);
            do add_plan_sym("room","P.BẾP",  #white, 17.5,10.4,22.0,12.6, mx_m,false);
            do add_plan_sym("room","P.NGỦ",  #white, 17.5,12.6,22.0,15.0, mx_m,false);
            do add_plan_sym("room","SẢNH",       #white, 15.0,7.0,17.5,12.6, mx_m,false);
            do add_plan_sym("room","",           #white, 16.4,12.6,17.5,15.0, mx_m,false);
            do add_plan_sym("room","TẮM & WC",   #white, 15.0,12.6,16.4,15.0, mx_m,false);

            create plan_element with: [
                etype:"flat_tag", elabel:m_code, ecolor:#yellow,
                shape:create_box(to_px(sym_x(18.5,mx_m)),to_py(7.2),
                                 to_px(sym_x(21.0,mx_m)),to_py(7.6))
            ];

            do add_plan_sym("wall","",rgb(54,69,79), 17.4,7.0,17.6,8.0, mx_m,false);
            do add_plan_sym("door","",rgb(205,133,63), 17.4,8.0,17.6,9.4, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 17.4,9.4,17.6,11.0, mx_m,false);
            do add_plan_sym("door","",rgb(205,133,63), 17.4,11.0,17.6,12.0, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 17.4,12.0,17.6,13.0, mx_m,false);
            do add_plan_sym("door","",rgb(205,133,63), 17.4,13.0,17.6,14.2, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 17.4,14.2,17.6,15.0, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 17.5,10.3,22.0,10.5, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 17.5,12.5,22.0,12.7, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 15.0,12.5,15.3,12.7, mx_m,false);
            do add_plan_sym("door","",rgb(205,133,63), 15.3,12.5,16.2,12.7, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 16.2,12.5,16.4,12.7, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 16.3,12.6,16.5,15.0, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 14.9,7.0,15.1,7.2, mx_m,false);
            do add_plan_sym("door","",rgb(205,133,63), 14.9,7.2,15.1,8.4, mx_m,false);
            do add_plan_sym("wall","",rgb(54,69,79), 14.9,8.4,15.1,15.0, mx_m,false);
            do add_plan_sym("facade_window","",#deepskyblue, 21.94,7.6,22.06,9.6, mx_m,false);
            do add_plan_sym("facade_window","",#deepskyblue, 21.94,10.8,22.06,12.2, mx_m,false);
            do add_plan_sym("facade_window","",#deepskyblue, 21.94,13.0,22.06,14.6, mx_m,false);
        }

        // Tường ranh giới giữa các căn hộ
        create plan_element with: [etype:"wall",elabel:"",ecolor:#black,shape:create_box(to_px(10.9),to_py(0.0),to_px(11.1),to_py(7.0))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:#black,shape:create_box(to_px(15.0),to_py(6.9),to_px(22.0),to_py(7.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:#black,shape:create_box(to_px(15.0),to_py(14.9),to_px(22.0),to_py(15.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:#black,shape:create_box(to_px(0.0),to_py(6.9),to_px(7.0),to_py(7.1))];
        create plan_element with: [etype:"wall",elabel:"",ecolor:#black,shape:create_box(to_px(0.0),to_py(14.9),to_px(7.0),to_py(15.1))];
    }

    // =========================================================================
    // 3. XỬ LÝ CLICK CHUỘT CHỌN TẦNG
    // =========================================================================
    action select_floor {
        point click_pt <- #user_location;
        if (click_pt.x >= 4.0 and click_pt.x <= 44.0) {
            ask floor_level_agt {
                if (click_pt.y >= self.y_top and click_pt.y <= self.y_bot) {
                    selected_floor      <- self.floor_id;
                    selected_floor_name <- self.floor_label;
                    ask floor_level_agt { self.is_selected <- (self.floor_id = selected_floor); }
                    write "Khảo sát Tầng: " + selected_floor_name + " (Floor ID: " + selected_floor + ")";
                    ask world { do build_active_floor_plan; }
                }
            }
        }
    }
}

// =============================================================================
// SPECIES
// =============================================================================

species floor_level_agt {
    int    floor_id;
    string floor_label;
    bool   is_selected <- false;
    float  y_top;
    float  y_bot;
    float  y_mid;

    // --- CÁC BIẾN QUẢN LÝ CLADDING 4 MẶT & NỘI THẤT (DUAL-LAYER SIMULATION) ---
    float clad_east  <- 0.0;   // 0.0: bình thường, 0.1-1.5: đang cháy (đỏ rực), >1.5: cháy kiệt (than đen)
    float clad_north <- 0.0;
    float clad_south <- 0.0;
    float clad_west  <- 0.0;

    bool  window_broken       <- false;   // Cửa sổ bị vỡ
    bool  interior_fire       <- false;   // Cháy nội thất căn hộ
    float floor_smoke_density <- 0.0;     // Mật độ khói (0.0 -> 1.0)
    int   fire_start_tick     <- -1;      // Thời điểm tầng này bắt đầu bị cháy (tick)
    float interior_burn_depth  <- 0.0;     // Độ sâu ngọn lửa đã lan vào trong từ cửa sổ (m)
    float interior_smoke_depth <- 0.0;     // Độ sâu khói độc đã lan tỏa vào trong (m) - lan nhanh gấp 2.5 - 3 lần lửa

    // Hàm chuyển đổi mức độ cháy Cladding sang màu trực quan
    rgb get_cladding_color(float c_val) {
        if (c_val <= 0.05) { return rgb(118,140,160); } // Bình thường (xanh xám kiến trúc)
        if (c_val > 1.5)   { return rgb(42,42,48); }     // Cháy kiệt (than đen xám)
        float r_ratio <- min([1.0, c_val / 1.2]);
        return rgb(255, int(160 * (1.0 - r_ratio)), 0); // Đang cháy (Vàng cam -> Đỏ rực)
    }

    aspect default {
        // Highlight tầng đang chọn
        if (is_selected) {
            draw rectangle(35.0, y_bot - y_top + 0.3) at_location {22.5, y_mid}
                color: rgb(255,245,175,140) border: #red;
            draw ("◄ TẦNG " + floor_label) at: {39.5, y_mid + 0.4}
                color: #red font: font("Arial", 8, #bold);
        }
        if (floor_id = 23) {
            draw "← 23th floor" at: {39.5, y_mid + 0.4}
                color: rgb(180,40,40) font: font("Arial", 9, #bold);
        }
        if (floor_id = 4) {
            draw "← 4th floor" at: {39.5, y_mid + 0.4}
                color: rgb(180,40,40) font: font("Arial", 9, #bold);
        }

        // =====================================================================
        // CỘT TRÁI: NORTH & SOUTH ELEVATIONS (x: 6.0 -> 21.0)
        //   Nửa trái (x: 6.0 -> 13.5): Mặt North
        //   Nửa phải (x: 13.5 -> 21.0): Mặt South
        // =====================================================================
        rgb col_north <- get_cladding_color(clad_north);
        rgb col_south <- get_cladding_color(clad_south);

        // Nửa trái: North
        draw rectangle(7.5, y_bot - y_top) at_location {9.75, y_mid}
            color: col_north border: rgb(85,102,118);
        // Nửa phải: South
        draw rectangle(7.5, y_bot - y_top) at_location {17.25, y_mid}
            color: col_south border: rgb(85,102,118);

        draw line([{6.0, y_bot},{21.0, y_bot}]) color: rgb(65,80,95);

        if (floor_id >= 4 and floor_id <= 23) {
            float win_h <- (y_bot - y_top) * 0.62;
            float win_y <- y_mid;
            draw line([{13.5, y_top},{13.5, y_bot}]) color: rgb(75,92,108);
            list<float> ns_bays <- [7.4, 9.4, 11.4, 15.6, 17.6, 19.6];
            loop bx over: ns_bays {
                // bx < 13.5 là mặt North (chỉ đỏ khi clad_north > 0.2)
                // bx > 13.5 là mặt South (chỉ đỏ khi clad_south > 0.2)
                bool is_bay_burning <- (bx < 13.5) ? (clad_north > 0.2) : (clad_south > 0.2);
                rgb win_color <- is_bay_burning ? rgb(255,60,0) : rgb(215,230,244);
                draw rectangle(1.6, win_h) at_location {bx, win_y} color: rgb(35,42,48);
                draw rectangle(0.70, win_h - 0.2) at_location {bx - 0.38, win_y} color: win_color;
                draw rectangle(0.70, win_h - 0.2) at_location {bx + 0.38, win_y} color: win_color;
                draw line([{bx, win_y - win_h/2.0},{bx, win_y + win_h/2.0}]) color: rgb(35,42,48);
            }
        } else if (floor_id = 24) {
            // Crown Tầng 24
            list<float> c_lines <- [8.0,10.0,12.0,15.0,17.0,19.0];
            loop lx over: c_lines { draw line([{lx, y_top},{lx, y_bot}]) color: rgb(70,85,100); }
        }

        // =====================================================================
        // CỘT PHẢI: EAST & WEST ELEVATIONS (x: 24.0 -> 39.0)
        //   Nửa trái (x: 24.0 -> 31.5): Mặt West (chỉ cháy khi clad_west > 0.2)
        //   Nửa phải (x: 31.5 -> 39.0): Mặt East (cháy đầu tiên khi clad_east > 0.2)
        // =====================================================================
        rgb col_west <- get_cladding_color(clad_west);
        rgb col_east <- get_cladding_color(clad_east);

        // Nửa trái: West
        draw rectangle(7.5, y_bot - y_top) at_location {27.75, y_mid}
            color: col_west border: rgb(85,102,118);
        // Nửa phải: East
        draw rectangle(7.5, y_bot - y_top) at_location {35.25, y_mid}
            color: col_east border: rgb(85,102,118);

        draw line([{24.0, y_bot},{39.0, y_bot}]) color: rgb(65,80,95);

        if (floor_id >= 4 and floor_id <= 23) {
            float win_h <- (y_bot - y_top) * 0.62;
            float win_y <- y_mid;
            draw line([{31.5, y_top},{31.5, y_bot}]) color: rgb(75,92,108);
            list<float> ew_bays <- [25.4, 27.8, 30.2, 32.8, 35.2, 37.6];
            loop bx over: ew_bays {
                // bx < 31.5 là mặt West (chỉ đỏ khi clad_west > 0.2)
                // bx > 31.5 là mặt East (chỉ đỏ khi clad_east > 0.2)
                bool bay_broken <- (bx > 31.5) ? (clad_east > 0.2) : (clad_west > 0.2);
                rgb win_color <- bay_broken ? rgb(255,60,0) : rgb(215,230,245);
                draw rectangle(1.8, win_h) at_location {bx, win_y} color: rgb(35,42,48);
                draw rectangle(0.48, win_h - 0.2) at_location {bx - 0.55, win_y} color: win_color;
                draw rectangle(0.48, win_h - 0.2) at_location {bx,        win_y} color: win_color;
                draw rectangle(0.48, win_h - 0.2) at_location {bx + 0.55, win_y} color: win_color;
                draw line([{bx-0.28, win_y-win_h/2.0},{bx-0.28, win_y+win_h/2.0}]) color: rgb(35,42,48);
                draw line([{bx+0.28, win_y-win_h/2.0},{bx+0.28, win_y+win_h/2.0}]) color: rgb(35,42,48);
            }
        } else if (floor_id = 24) {
            // Crown Tầng 24
            list<float> c_lines_ew <- [26.0,28.0,30.0,33.0,35.0,37.0];
            loop lx over: c_lines_ew { draw line([{lx, y_top},{lx, y_bot}]) color: rgb(70,85,100); }
        }

        // Báo khói/lửa tầng nếu có cháy
        if (clad_east > 0.1 or clad_north > 0.1 or clad_south > 0.1 or clad_west > 0.1) {
            draw circle(0.25) at_location {4.8, y_mid} color: #red;
        }
    }
}

species plan_element {
    string etype;
    string elabel;
    rgb    ecolor;

    aspect default {
        if (etype = "wall" or etype = "outer_wall") {
            draw shape color: ecolor border: #black;
        } else if (etype = "door") {
            draw shape color: ecolor border: #black;
        } else if (etype = "facade_window") {
            draw shape color: ecolor border: #darkblue;
        } else if (etype = "column") {
            draw shape color: ecolor border: #black;
        } else if (etype = "origin_fridge") {
            draw shape color: ecolor border: #black;
            draw "ORIGIN" at: {location.x - 0.9, location.y + 0.3}
                color: #yellow font: font("Arial", 8, #bold);
        } else if (etype = "furniture") {
            draw shape color: ecolor border: rgb(40,45,55);
            if (elabel != "") {
                draw elabel at: {location.x - (length(elabel) * 0.16), location.y + 0.25}
                    color: rgb(25,30,45) font: font("Arial", 7, #bold);
            }
        } else if (etype = "stair_box") {
            draw shape color: ecolor border: rgb(40,40,40);
            float mid_x <- (shape.points[0].x + shape.points[1].x) / 2.0;
            float top_y <- shape.points[0].y;
            float bot_y <- shape.points[2].y;
            draw line([{mid_x, top_y + 0.8},{mid_x, bot_y - 0.8}]) color: rgb(50,50,50);
            loop i from: 0 to: 8 {
                float step_y <- top_y + 1.0 + (i * 0.85);
                draw line([{shape.points[0].x, step_y},{mid_x, step_y}]) color: rgb(90,90,90);
                draw line([{mid_x, step_y},{shape.points[1].x, step_y}]) color: rgb(90,90,90);
            }
            draw "THANG BỘ" at: {mid_x - 1.2, top_y + 0.8}
                color: rgb(180,30,30) font: font("Arial", 11, #bold);
        } else if (etype = "lift_cab") {
            draw shape color: ecolor border: rgb(40,40,40);
            if (elabel != "") {
                draw elabel at: {location.x - 0.9, location.y + 0.35}
                    color: rgb(20,20,20) font: font("Arial", 11, #bold);
            }
        } else if (etype = "flat_tag") {
            draw elabel at: {location.x - (length(elabel) * 0.22), location.y}
                color: ecolor font: font("Arial", 12, #bold);
        } else {
            // room / lobby / riser
            draw shape color: ecolor;
            if (elabel != "") {
                float lum <- (ecolor.red * 0.299 + ecolor.green * 0.587 + ecolor.blue * 0.114);
                rgb t_col <- (lum > 130.0) ? rgb(15,15,15) : #white;
                draw elabel at: {location.x - (length(elabel) * 0.20), location.y + 0.35}
                    color: t_col font: font("Arial", 11, #bold);
            }
        }
    }
}

species plan_label {
    string m_text;
    string s_text;

    aspect default {
        draw m_text at: {location.x, location.y - 0.8}
            color: rgb(15,25,60) font: font("Arial", 13, #bold);
        draw s_text at: {location.x, location.y + 0.8}
            color: rgb(80,90,110) font: font("Arial", 9, #plain);
    }
}

species screen_decor {
    string dtype;
    string label;

    aspect default {
        if (dtype = "header") {
            draw label at: location color: rgb(20,35,80) font: font("Arial", 13, #bold);
        } else if (dtype = "title_left") {
            draw label at: location color: rgb(45,55,75) font: font("Arial", 11, #bold);
        } else if (dtype = "separator") {
            draw shape color: rgb(185,195,210);
        } else if (dtype = "fig2_label") {
            draw label at: location color: rgb(15,55,130) font: font("Arial", 11, #bold);
        } else if (dtype = "fig2_caption") {
            draw label at: location color: rgb(40,50,70) font: font("Arial", 10, #bold);
        }
    }
}
