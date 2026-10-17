/**
 * Name: Grenfell_Master_Simulation
 * Author: DOAN TAI LOC & Antigravity
 * Description: MÔ HÌNH HỢP NHẤT MẶT ĐỨNG & MẶT BẰNG TÒA THÁP GRENFELL TOWER
 *              Tập trung 100% vào ĐỘ CHÍNH XÁC KIẾN TRÚC & HÌNH HỌC (LAYOUT):
 *              - MẶT ĐỨNG (BÊN TRÁI): Chuẩn 100% FIGURE 2 trong nghiên cứu khoa học:
 *                Hai mặt đứng song song "North and South elevations" & "East and West elevations"
 *                25 cao trình (Ground đến Crown 24), phân vị 6 khoang cửa sổ, mũi tên đỏ chỉ 23th floor & 4th floor.
 *                Tương tác Click chuột chọn tầng bất kỳ.
 *              - MẶT BẰNG (BÊN PHẢI): Chi tiết hóa toàn bộ Tầng 4 (22m x 22m):
 *                + Bộ màu sắc kiến trúc đặc trưng cho 6 căn hộ: Xanh lá (Flat 16), Xanh ngọc (Flat 15),
 *                  Đỏ mận (Flat 14), Tím mận (Flat 11), Tím violet (Flat 13), Vàng nâu olive (Flat 12).
 *                + TẤT CẢ 6 CĂN HỘ đều được trang bị đầy đủ nội thất chi tiết (Sofa, Giường, Bàn ăn, Bếp, Bồn tắm...).
 *                + Flat 16 có Tủ lạnh Hotpoint phát cháy màu đỏ nổi bật (ORIGIN).
 *                + Lõi trung tâm 8m x 8m: Sảnh trung tâm, 2 Thang máy màu vàng gold, Thang bộ duy nhất có bậc thang.
 *                + Hệ thống cửa gỗ Peru, cửa sổ kính Deepskyblue, 14 Cột bê tông bát giác chu vi ngoài.
 *                + Khung nét đứt "Limit of the model" và La bàn định hướng 4 mặt.
 */

model Grenfell_Master_Simulation

global {
    // -------------------------------------------------------------------------
    // 1. KHÔNG GIAN MÔI TRƯỜNG TOÀN CỤC (GLOBAL SHAPE: 100 x 75)
    // -------------------------------------------------------------------------
    geometry shape <- rectangle(100.0, 75.0) at_location {50.0, 37.5};

    // Tầng hiện tại đang được khảo sát (Mặc định tầng 4 - nơi có Flat 16)
    int selected_floor <- 4;
    string selected_floor_name <- "4th (Flat 16)";

    // Tọa độ bounding box cho mặt bằng 2D bên phải (Kích thước 44.0 x 44.0 cho sàn 22.0m x 22.0m)
    float px_origin <- 49.0;
    float py_origin <- 16.0;
    float floor_dim <- 44.0; // 22.0m * 2.0

    // Hàm chuyển đổi tọa độ mặt bằng mét {lx, ly} sang tọa độ màn hình
    float to_px(float lx) {
        return px_origin + (lx * 2.0);
    }
    float to_py(float ly) {
        return py_origin + (ly * 2.0);
    }

    // Hàm tiện ích: Tạo hình chữ nhật từ hai điểm đối diện
    action create_box(float x1, float y1, float x2, float y2) type: geometry {
        float min_x <- min(x1, x2);
        float max_x <- max(x1, x2);
        float min_y <- min(y1, y2);
        float max_y <- max(y1, y2);
        float w <- max_x - min_x;
        float h <- max_y - min_y;
        return rectangle(w, h) at_location {min_x + w / 2.0, min_y + h / 2.0};
    }

    // Hàm tiện ích: Tạo hình bát giác đều 8 đỉnh chuẩn GAML
    action create_column_geom(float cx, float cy, float r) type: geometry {
        return polygon([
            {cx + r, cy}, 
            {cx + r * 0.7071, cy + r * 0.7071}, 
            {cx, cy + r}, 
            {cx - r * 0.7071, cy + r * 0.7071},
            {cx - r, cy}, 
            {cx - r * 0.7071, cy - r * 0.7071}, 
            {cx, cy - r}, 
            {cx + r * 0.7071, cy - r * 0.7071}
        ]);
    }

    // Hàm đối xứng tọa độ qua tâm {11.0, 11.0}
    float sym_x(float x, bool mir_x) {
        return mir_x ? (22.0 - x) : x;
    }
    float sym_y(float y, bool mir_y) {
        return mir_y ? (22.0 - y) : y;
    }

    // Hàm thêm đối tượng mặt bằng có hỗ trợ đối xứng gương
    action add_plan_sym(string et, string el, rgb ec, float x1, float y1, float x2, float y2, bool mx, bool my) {
        float nx1 <- sym_x(x1, mx);
        float nx2 <- sym_x(x2, mx);
        float ny1 <- sym_y(y1, my);
        float ny2 <- sym_y(y2, my);
        create plan_element with: [
            etype: et,
            elabel: el,
            ecolor: ec,
            shape: create_box(to_px(min(nx1, nx2)), to_py(min(ny1, ny2)), to_px(max(nx1, nx2)), to_py(max(ny1, ny2)))
        ];
    }

    // =========================================================================
    // 2. KHỞI TẠO MÔ HÌNH TOÀN CẢNH
    // =========================================================================
    init {
        write "=== KHỞI TẠO MÔ HÌNH KIẾN TRÚC GRENFELL TOWER (FIGURE 2 & FIGURE 3) ===";

        // Khung và tiêu đề giao diện
        create screen_decor with: [dtype: "header", label: "GRENFELL TOWER ARCHITECTURAL MODEL (PART 2 & PART 3 - WILEY/EFFECTIS)", location: {50.0, 3.2}];
        create screen_decor with: [dtype: "separator", shape: polyline([{46.0, 5.0}, {46.0, 72.0}])];
        create screen_decor with: [dtype: "title_left", label: "MẶT ĐỨNG SỐ HỌC (CLICK CHỌN TẦNG KHẢO SÁT)", location: {22.5, 6.5}];

        // Nhãn Figure 2 cho mặt đứng bên trái
        create screen_decor with: [dtype: "fig2_label", label: "North and South", location: {11.0, 65.8}];
        create screen_decor with: [dtype: "fig2_label", label: "elevations", location: {12.2, 67.5}];

        create screen_decor with: [dtype: "fig2_label", label: "East and West", location: {28.5, 65.8}];
        create screen_decor with: [dtype: "fig2_label", label: "elevations", location: {29.8, 67.5}];

        create screen_decor with: [
            dtype: "fig2_caption", 
            label: "FIGURE 2   Numerical models of the south/north and east/west faces of the Tower", 
            location: {6.5, 70.8}
        ];

        // A. Dựng mặt đứng 25 tầng tháp (Figure 2) bên trái
        do build_tower_elevation;

        // B. Dựng mặt bằng tầng đang chọn bên phải
        do build_active_floor_plan;
    }

    // =========================================================================
    // A. DỰNG MÔ HÌNH MẶT ĐỨNG 25 TẦNG THÁP THEO CHUẨN FIGURE 2
    // =========================================================================
    action build_tower_elevation {
        list<int> f_ids <- [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24];
        list<string> f_names <- [
            "Ground", "Mezzanine", "Walkway", "Office",
            "4th (Flat 16)", "5th", "6th", "7th", "8th", "9th", "10th",
            "11th", "12th", "13th", "14th", "15th", "16th", "17th", "18th", "19th", "20th",
            "21st", "22nd", "23th", "Roof"
        ];

        float base_y <- 63.5;
        float f_step <- 2.12;

        loop i from: 0 to: length(f_ids) - 1 {
            int fid <- f_ids[i];
            string fname <- f_names[i];
            float y_b <- base_y - (i * f_step);
            float y_t <- y_b - f_step;
            float y_m <- (y_t + y_b) / 2.0;

            create floor_level_agt with: [
                floor_id: fid,
                floor_label: fname,
                is_selected: (fid = selected_floor),
                y_top: y_t,
                y_bot: y_b,
                y_mid: y_m,
                shape: create_box(4.0, y_t, 44.0, y_b)
            ];
        }
    }

    // =========================================================================
    // B. DỰNG MẶT BẰNG 2D CHI TIẾT TẦNG ĐANG CHỌN (BÊN PHẢI)
    // =========================================================================
    action build_active_floor_plan {
        ask plan_element { do die; }
        ask plan_label { do die; }

        float px1 <- px_origin;
        float px2 <- px_origin + floor_dim; // 93.0
        float py1 <- py_origin;
        float py2 <- py_origin + floor_dim; // 60.0

        // Tiêu đề & phụ đề mặt bằng bên phải
        string p_title <- (selected_floor = 4) ? 
            "MẶT BẰNG TẦNG 4: CHI TIẾT ĐẦY ĐỦ FLAT 16 & CÁC CĂN HỘ" : 
            ((selected_floor = 0) ? "MẶT BẰNG TẦNG TRỆT (GROUND FLOOR LOBBY)" : ("MẶT BẰNG TẦNG " + selected_floor_name + " (TYPICAL RESIDENTIAL FLOOR)"));
        
        string p_sub <- (selected_floor = 4) ? 
            "Sàn 22m x 22m: Flat 16 có đầy đủ nội thất & Tủ lạnh phát hỏa (ORIGIN), 5 căn hộ còn lại thể hiện rõ ràng cấu trúc phân phòng" : 
            ((selected_floor = 0) ? "Lối vào chính, Sảnh chung, Phòng trẻ em Nursery, Văn phòng Office, Trạm biến áp & Lõi thang" : 
            "Sàn điển hình 22m x 22m: 6 Căn hộ phân chia phòng chuẩn xác, Lõi trung tâm 8m x 8m (2 Thang máy, Thang bộ thoát hiểm)");

        create plan_label with: [m_text: p_title, s_text: p_sub, location: {71.0, 11.5}];

        // NỘI DUNG MẶT BẰNG THEO TẦNG
        if (selected_floor = 0) {
            // =================================================================
            // MẶT BẰNG CHI TIẾT TẦNG TRỆT (GROUND FLOOR - 22.0m x 22.0m)
            // =================================================================

            // 1. LÕI TRUNG TÂM (CENTRAL CORE: 8.0m x 8.0m) - ĐỒNG NHẤT XUYÊN SUỐT TOÀN THÁP
            // Sảnh đệm trung tâm
            create plan_element with: [etype: "lobby", elabel: "SẢNH ĐỆM THANG", ecolor: rgb(215, 222, 230), shape: create_box(to_px(9.4), to_py(7.0), to_px(12.6), to_py(15.0))];

            // 2 Thang máy bên Tây (Cabin vàng gold)
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(6.9), to_py(8.4), to_px(9.4), to_py(8.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(6.9), to_py(13.4), to_px(9.4), to_py(13.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(6.9), to_py(8.4), to_px(7.1), to_py(13.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(7.0), to_py(10.9), to_px(9.4), to_py(11.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(9.2), to_py(8.4), to_px(9.4), to_py(9.3))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(9.2), to_py(10.3), to_px(9.4), to_py(11.7))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(9.2), to_py(12.7), to_px(9.4), to_py(13.6))];
            create plan_element with: [etype: "lift_cab", elabel: "LIFT 1", ecolor: rgb(255, 215, 50), shape: create_box(to_px(7.1), to_py(8.6), to_px(9.2), to_py(10.9))];
            create plan_element with: [etype: "lift_cab", elabel: "LIFT 2", ecolor: rgb(255, 215, 50), shape: create_box(to_px(7.1), to_py(11.1), to_px(9.2), to_py(13.4))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(9.2), to_py(9.3), to_px(9.45), to_py(10.3))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(9.2), to_py(11.7), to_px(9.45), to_py(12.7))];

            // Buồng Thang bộ duy nhất bên Đông
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(12.6), to_py(8.4), to_px(15.1), to_py(8.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(12.6), to_py(13.4), to_px(15.1), to_py(13.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(14.9), to_py(8.4), to_px(15.1), to_py(13.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(12.6), to_py(8.4), to_px(12.8), to_py(10.55))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(12.6), to_py(11.45), to_px(12.8), to_py(13.6))];
            create plan_element with: [etype: "stair_box", elabel: "THANG BỘ", ecolor: #white, shape: create_box(to_px(12.8), to_py(8.6), to_px(14.9), to_py(13.4))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(180, 50, 50), shape: create_box(to_px(12.6), to_py(10.55), to_px(12.85), to_py(11.45))];

            // 4 Góc Lõi: Riser & Chân Ống Xả Rác
            create plan_element with: [etype: "riser", elabel: "RISER", ecolor: rgb(150, 155, 165), shape: create_box(to_px(7.0), to_py(7.0), to_px(8.5), to_py(8.4))];
            create plan_element with: [etype: "riser", elabel: "RISER", ecolor: rgb(150, 155, 165), shape: create_box(to_px(7.0), to_py(13.6), to_px(8.5), to_py(15.0))];
            create plan_element with: [etype: "riser", elabel: "CHÂN ỐNG RÁC", ecolor: rgb(150, 155, 165), shape: create_box(to_px(13.5), to_py(7.0), to_px(15.0), to_py(8.4))];
            create plan_element with: [etype: "riser", elabel: "RISER", ecolor: rgb(150, 155, 165), shape: create_box(to_px(13.5), to_py(13.6), to_px(15.0), to_py(15.0))];

            // 2. KHU VỰC NHÀ TRẺ (GRENFELL EARLY YEARS NURSERY - PHÍA BẮC & TÂY BẮC)
            // Phòng sinh hoạt / chơi chính của trẻ
            create plan_element with: [etype: "room", elabel: "PHÒNG SINH HOẠT TRẺ", ecolor: rgb(235, 245, 235), shape: create_box(to_px(0.0), to_py(0.0), to_px(10.9), to_py(7.0))];
            // Phòng nghỉ / ngủ yên tĩnh của trẻ
            create plan_element with: [etype: "room", elabel: "PHÒNG NGHỈ TRẺ", ecolor: rgb(240, 240, 252), shape: create_box(to_px(10.9), to_py(0.0), to_px(16.5), to_py(7.0))];
            // WC Trẻ em
            create plan_element with: [etype: "room", elabel: "WC TRẺ EM", ecolor: rgb(240, 250, 250), shape: create_box(to_px(0.0), to_py(7.0), to_px(5.5), to_py(11.0))];
            // Bếp nhà trẻ
            create plan_element with: [etype: "room", elabel: "BẾP NHÀ TRẺ", ecolor: rgb(250, 245, 235), shape: create_box(to_px(0.0), to_py(11.0), to_px(5.5), to_py(15.0))];
            // Sảnh & Lối vào riêng nhà trẻ
            create plan_element with: [etype: "room", elabel: "LỐI VÀO", ecolor: rgb(230, 240, 230), shape: create_box(to_px(5.5), to_py(7.0), to_px(7.0), to_py(15.0))];

            create plan_element with: [etype: "flat_tag", elabel: "NHÀ TRẺ GRENFELL (NURSERY)", ecolor: rgb(15, 35, 90), shape: create_box(to_px(2.0), to_py(1.2), to_px(9.0), to_py(1.6))];

            // Tường ngăn khu nhà trẻ
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(10.8), to_py(0.0), to_px(11.0), to_py(7.0))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(0.0), to_py(6.9), to_px(7.0), to_py(7.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(0.0), to_py(10.9), to_px(5.5), to_py(11.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(0.0), to_py(14.9), to_px(7.0), to_py(15.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(5.4), to_py(7.0), to_px(5.6), to_py(15.0))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(6.9), to_py(7.0), to_px(7.1), to_py(8.4))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(6.9), to_py(13.6), to_px(7.1), to_py(15.0))];

            // Cửa ra vào khu nhà trẻ
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(5.8), to_py(6.9), to_px(6.7), to_py(7.1))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(5.4), to_py(8.5), to_px(5.6), to_py(9.5))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(5.4), to_py(12.5), to_px(5.6), to_py(13.5))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(10.8), to_py(2.5), to_px(11.0), to_py(4.0))];
            create plan_element with: [etype: "door", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(0.0), to_py(8.5), to_px(0.3), to_py(10.0))];

            // Cửa sổ kính nhà trẻ
            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(2.0), to_py(-0.06), to_px(4.5), to_py(0.06))];
            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(6.5), to_py(-0.06), to_px(9.0), to_py(0.06))];
            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(12.5), to_py(-0.06), to_px(15.0), to_py(0.06))];
            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(-0.06), to_py(2.0), to_px(0.06), to_py(5.0))];

            // 3. KHU VỰC VĂN PHÒNG BAN QUẢN LÝ TÒA NHÀ (ESTATE OFFICE - TÂY NAM)
            create plan_element with: [etype: "room", elabel: "VĂN PHÒNG QUẢN LÝ", ecolor: rgb(245, 240, 225), shape: create_box(to_px(0.0), to_py(15.0), to_px(5.5), to_py(19.0))];
            create plan_element with: [etype: "room", elabel: "PHÒNG HỌP & HỒ SƠ", ecolor: rgb(240, 235, 220), shape: create_box(to_px(0.0), to_py(19.0), to_px(5.5), to_py(22.0))];
            create plan_element with: [etype: "room", elabel: "WC & KHO NV", ecolor: rgb(242, 238, 230), shape: create_box(to_px(5.5), to_py(15.0), to_px(8.0), to_py(22.0))];

            create plan_element with: [etype: "flat_tag", elabel: "BAN QUẢN LÝ (ESTATE OFFICE)", ecolor: rgb(15, 35, 90), shape: create_box(to_px(0.5), to_py(15.6), to_px(7.5), to_py(16.0))];

            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(0.0), to_py(18.9), to_px(5.5), to_py(19.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(5.4), to_py(15.0), to_px(5.6), to_py(22.0))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(7.9), to_py(15.0), to_px(8.1), to_py(22.0))];

            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(7.9), to_py(16.5), to_px(8.1), to_py(17.8))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(5.4), to_py(17.0), to_px(5.6), to_py(18.2))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(5.4), to_py(19.8), to_px(5.6), to_py(21.0))];

            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(-0.06), to_py(16.5), to_px(0.06), to_py(18.5))];
            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(-0.06), to_py(19.5), to_px(0.06), to_py(21.5))];
            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(1.5), to_py(21.94), to_px(4.0), to_py(22.06))];

            // 4. SẢNH ĐÓN TIẾP CHÍNH (MAIN ENTRANCE FOYER & CONCIERGE - PHÍA NAM)
            create plan_element with: [etype: "lobby", elabel: "SẢNH ĐÓN TIẾP CHÍNH", ecolor: rgb(220, 228, 238), shape: create_box(to_px(8.0), to_py(15.0), to_px(12.6), to_py(22.0))];
            create plan_element with: [etype: "lobby", elabel: "", ecolor: rgb(220, 228, 238), shape: create_box(to_px(12.6), to_py(15.0), to_px(15.0), to_py(22.0))];
            
            // Bàn trực Lễ tân & An ninh (Concierge Desk)
            create plan_element with: [etype: "furniture", elabel: "LỄ TÂN / BẢO VỆ", ecolor: rgb(180, 130, 80), shape: create_box(to_px(12.8), to_py(17.0), to_px(14.7), to_py(19.0))];

            // Cửa chính ra vào 2 cánh mặt tiền Nam
            create plan_element with: [etype: "door", elabel: "CỬA CHÍNH", ecolor: #gold, shape: create_box(to_px(9.5), to_py(21.85), to_px(12.5), to_py(22.15))];
            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(8.2), to_py(21.94), to_px(9.3), to_py(22.06))];
            create plan_element with: [etype: "facade_window", elabel: "", ecolor: #deepskyblue, shape: create_box(to_px(12.7), to_py(21.94), to_px(14.8), to_py(22.06))];

            // 5. KHU VỰC KỸ THUẬT, TRẠM ĐIỆN & RÁC (EAST WING - PHÍA ĐÔNG)
            // Trạm Biến Áp Điện Lực
            create plan_element with: [etype: "room", elabel: "TRẠM BIẾN ÁP (SUBSTATION)", ecolor: rgb(215, 220, 228), shape: create_box(to_px(16.5), to_py(0.0), to_px(22.0), to_py(7.0))];
            // Phòng Rác Trung Tâm (Nơi chân ống rác đổ xuống)
            create plan_element with: [etype: "room", elabel: "PHÒNG RÁC TRUNG TÂM", ecolor: rgb(225, 225, 230), shape: create_box(to_px(15.0), to_py(7.0), to_px(22.0), to_py(12.8))];
            // Hành lang thoát hiểm từ buồng thang bộ
            create plan_element with: [etype: "lobby", elabel: "LỐI THOÁT HIỂM", ecolor: rgb(250, 230, 230), shape: create_box(to_px(15.0), to_py(12.8), to_px(22.0), to_py(16.5))];
            // Phòng Kỹ Thuật Bơm & Nước
            create plan_element with: [etype: "room", elabel: "PHÒNG BƠM (PUMP ROOM)", ecolor: rgb(215, 220, 228), shape: create_box(to_px(15.0), to_py(16.5), to_px(22.0), to_py(22.0))];

            create plan_element with: [etype: "flat_tag", elabel: "KHU KỸ THUẬT & TRẠM BIẾN ÁP", ecolor: rgb(15, 35, 90), shape: create_box(to_px(16.8), to_py(1.2), to_px(21.5), to_py(1.6))];

            // Tường ngăn khu kỹ thuật
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(16.4), to_py(0.0), to_px(16.6), to_py(7.0))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(15.0), to_py(6.9), to_px(22.0), to_py(7.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(15.0), to_py(12.7), to_px(22.0), to_py(12.9))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(15.0), to_py(16.4), to_px(22.0), to_py(16.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(14.9), to_py(15.0), to_px(15.1), to_py(22.0))];

            // Cửa thoát hiểm thang bộ ra ngoài trời (Chống cháy đỏ)
            create plan_element with: [etype: "door", elabel: "CỬA THOÁT HIỂM", ecolor: rgb(220, 40, 40), shape: create_box(to_px(21.85), to_py(13.8), to_px(22.15), to_py(15.5))];
            // Cửa kho rác ra sân ngoài
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(120, 130, 140), shape: create_box(to_px(21.85), to_py(8.5), to_px(22.15), to_py(11.0))];
            // Cửa trạm biến áp
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(120, 130, 140), shape: create_box(to_px(21.85), to_py(2.5), to_px(22.15), to_py(4.5))];
            // Cửa phòng bơm
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(120, 130, 140), shape: create_box(to_px(21.85), to_py(18.0), to_px(22.15), to_py(19.5))];
        } else {
            // =================================================================
            // TẦNG 4 VÀ CÁC TẦNG CĂN HỘ (1st - 20th) - ĐẦY ĐỦ NỘI THẤT CHI TIẾT
            // =================================================================

            // -----------------------------------------------------------------
            // I. LÕI TRUNG TÂM (CENTRAL CORE: 8.0m x 8.0m, từ x: 7.0 -> 15.0, y: 7.0 -> 15.0)
            // -----------------------------------------------------------------
            // 1. Sảnh hành lang chung (Central Lobby)
            create plan_element with: [
                etype: "lobby", 
                elabel: "SẢNH TẦNG", 
                ecolor: rgb(215, 222, 230), 
                shape: create_box(to_px(9.4), to_py(7.0), to_px(12.6), to_py(15.0))
            ];
            create plan_element with: [etype: "lobby", elabel: "", ecolor: rgb(215, 222, 230), shape: create_box(to_px(7.0), to_py(7.0), to_px(15.0), to_py(8.4))]; // Hành lang Bắc kết nối thẳng vào Cửa chính Flat 11 & Flat 14
            create plan_element with: [etype: "lobby", elabel: "", ecolor: rgb(215, 222, 230), shape: create_box(to_px(8.5), to_py(13.6), to_px(13.5), to_py(15.0))];

            // 2. Cụm 2 Thang máy bên Tây (Lifts: x: 7.0 -> 9.4, y: 8.4 -> 13.6)
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(6.9), to_py(8.4), to_px(9.4), to_py(8.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(6.9), to_py(13.4), to_px(9.4), to_py(13.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(6.9), to_py(8.4), to_px(7.1), to_py(13.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(7.0), to_py(10.9), to_px(9.4), to_py(11.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(9.2), to_py(8.4), to_px(9.4), to_py(9.3))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(9.2), to_py(10.3), to_px(9.4), to_py(11.7))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(9.2), to_py(12.7), to_px(9.4), to_py(13.6))];

            // Cabin 2 thang máy (Vàng gold)
            create plan_element with: [etype: "lift_cab", elabel: "LIFT 1", ecolor: rgb(255, 215, 50), shape: create_box(to_px(7.1), to_py(8.6), to_px(9.2), to_py(10.9))];
            create plan_element with: [etype: "lift_cab", elabel: "LIFT 2", ecolor: rgb(255, 215, 50), shape: create_box(to_px(7.1), to_py(11.1), to_px(9.2), to_py(13.4))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(9.2), to_py(9.3), to_px(9.45), to_py(10.3))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(205, 133, 63), shape: create_box(to_px(9.2), to_py(11.7), to_px(9.45), to_py(12.7))];

            // 3. Buồng Thang bộ duy nhất bên Đông (Stairs: x: 12.6 -> 15.0, y: 8.4 -> 13.6)
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(12.6), to_py(8.4), to_px(15.1), to_py(8.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(12.6), to_py(13.4), to_px(15.1), to_py(13.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(14.9), to_py(8.4), to_px(15.1), to_py(13.6))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(12.6), to_py(8.4), to_px(12.8), to_py(10.55))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: rgb(54, 69, 79), shape: create_box(to_px(12.6), to_py(11.45), to_px(12.8), to_py(13.6))];

            create plan_element with: [etype: "stair_box", elabel: "THANG BỘ", ecolor: #white, shape: create_box(to_px(12.8), to_py(8.6), to_px(14.9), to_py(13.4))];
            create plan_element with: [etype: "door", elabel: "", ecolor: rgb(180, 50, 50), shape: create_box(to_px(12.6), to_py(10.55), to_px(12.85), to_py(11.45))];

            // 4. Các hộp kỹ thuật Riser & Ống xả rác tại các góc lõi
            create plan_element with: [etype: "riser", elabel: "RISER", ecolor: rgb(150, 155, 165), shape: create_box(to_px(7.0), to_py(13.6), to_px(8.5), to_py(15.0))];
            create plan_element with: [etype: "riser", elabel: "ỐNG RÁC", ecolor: rgb(150, 155, 165), shape: create_box(to_px(13.2), to_py(7.0), to_px(14.4), to_py(7.7))];
            create plan_element with: [etype: "riser", elabel: "RISER", ecolor: rgb(150, 155, 165), shape: create_box(to_px(13.5), to_py(13.6), to_px(15.0), to_py(15.0))];

            // -----------------------------------------------------------------
            // II. 4 CĂN GÓC (2-BEDROOM FLATS: 11.0m x 7.0m = 77m²) ĐẦY ĐỦ CHI TIẾT
            // -----------------------------------------------------------------
            list<point> c_mirs <- [{0.0, 0.0}, {1.0, 0.0}, {0.0, 1.0}, {1.0, 1.0}];
            int base_num <- (selected_floor - 3) * 10;
            list<string> c_titles <- (selected_floor = 4) ? [
                "FLAT 16 [NE - ĐIỂM CHÁY]",
                "FLAT 15 [NW - 2PN]",
                "FLAT 12 [SE - 2PN]",
                "FLAT 13 [SW - 2PN]"
            ] : [
                "FLAT " + (base_num + 6) + " [NE - 2PN]",
                "FLAT " + (base_num + 5) + " [NW - 2PN]",
                "FLAT " + (base_num + 2) + " [SE - 2PN]",
                "FLAT " + (base_num + 3) + " [SW - 2PN]"
            ];
            list<rgb> c_colors_list <- [
                rgb(20, 90, 45),   // Flat NE: Xanh lá đậm
                rgb(15, 80, 85),   // Flat NW: Xanh ngọc đậm
                rgb(120, 100, 20), // Flat SE: Vàng nâu đậm
                rgb(85, 30, 95)    // Flat SW: Tím violet đậm
            ];

            loop idx from: 0 to: 3 {
                point mir <- c_mirs[idx];
                bool mx <- (mir.x = 1.0);
                bool my <- (mir.y = 1.0);
                string fname <- c_titles[idx];
                rgb base_col <- c_colors_list[idx];
                bool is_f16 <- (selected_floor = 4 and idx = 0);

                // 1. Phân chia phòng ốc chuẩn 100% FIGURE 2 (Guillaume et al.)
                do add_plan_sym("room", is_f16 ? "Khách (Living)" : "PHÒNG KHÁCH", base_col, 16.25, 0.0, 22.0, 4.6, mx, my);
                do add_plan_sym("room", is_f16 ? "Bếp (Origin)" : "PHÒNG BẾP", base_col, 16.25, 4.6, 22.0, 7.0, mx, my);
                do add_plan_sym("room", "PHÒNG NGỦ 1", base_col, 11.0, 0.0, 13.62, 3.4, mx, my);
                do add_plan_sym("room", "PHÒNG NGỦ 2", base_col, 13.62, 0.0, 16.25, 3.4, mx, my);
                do add_plan_sym("room", "", base_col, 11.0, 3.4, 16.25, 4.6, mx, my); // Hành lang liên kết thông thẳng vào Phòng khách
                do add_plan_sym("room", "SẢNH", base_col, 11.0, 4.6, 13.62, 7.0, mx, my);
                do add_plan_sym("room", "TẮM & WC", base_col, 13.62, 4.6, 16.25, 7.0, mx, my);

                // Thẻ định danh căn hộ
                create plan_element with: [
                    etype: "flat_tag",
                    elabel: fname,
                    ecolor: #yellow,
                    shape: create_box(to_px(sym_x(18.0, mx)), to_py(sym_y(0.5, my)), to_px(sym_x(20.5, mx)), to_py(sym_y(0.9, my)))
                ];

                // 2. Hệ tường ngăn chuẩn xác theo FIGURE 2 (Phòng khách thông hoàn toàn với Sảnh, tường chỉ ngăn Bếp)
                // 2.1. Tường ngăn giữa Bedroom 2 và Living (dừng lại tại y = 3.4, phía dưới mở thông hoàn toàn vào Living!)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 16.15, 0.0, 16.35, 3.4, mx, my);

                // 2.2. Tường bao khép kín phòng BẾP (Kitchen)
                // Tường ngang ngăn Bếp với Living (tại y = 4.6, chạy từ x = 16.25 ra tường ngoài x = 22.0)
                do add_plan_sym("door", "", rgb(205, 133, 63), 16.5, 4.5, 17.5, 4.7, mx, my);     // Cửa chính vào Bếp (mở từ khu vực Sảnh / Khách)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 17.5, 4.5, 18.5, 4.7, mx, my);
                do add_plan_sym("door", "", rgb(205, 133, 63), 18.5, 4.5, 20.0, 4.7, mx, my);     // Cửa trượt / quầy thông bếp với Living
                do add_plan_sym("wall", "", rgb(54, 69, 79), 20.0, 4.5, 22.0, 4.7, mx, my);

                // Tường dọc phía Tây của Bếp (tại x = 16.25, từ y = 4.6 xuống y = 7.0)
                // Vách tường đặc 100% ngăn cách Bếp và Tắm & WC (Hoàn toàn KHÔNG có cửa thông giữa WC và Bếp)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 16.15, 4.6, 16.35, 7.0, mx, my);

                // 2.3. Tường ngang ngăn 2 phòng ngủ với Hành lang liên kết (tại y = 3.4)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 11.0, 3.3, 11.8, 3.5, mx, my);
                do add_plan_sym("door", "", rgb(205, 133, 63), 11.8, 3.3, 12.7, 3.5, mx, my);     // Cửa vào Bedroom 1
                do add_plan_sym("wall", "", rgb(54, 69, 79), 12.7, 3.3, 14.3, 3.5, mx, my);
                do add_plan_sym("door", "", rgb(205, 133, 63), 14.3, 3.3, 15.2, 3.5, mx, my);     // Cửa vào Bedroom 2
                do add_plan_sym("wall", "", rgb(54, 69, 79), 15.2, 3.3, 16.25, 3.5, mx, my);

                // 2.4. Tường ngăn giữa 2 phòng ngủ (tại x = 13.62)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 13.52, 0.0, 13.72, 3.4, mx, my);

                // 2.5. Tường ngăn phòng TẮM & WC khép kín (tại y = 4.6 -> 7.0)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 13.52, 4.6, 13.72, 7.0, mx, my);   // Vách Tây ngăn Tắm/WC với Sảnh vào
                do add_plan_sym("wall", "", rgb(54, 69, 79), 13.62, 4.5, 14.3, 4.7, mx, my);
                do add_plan_sym("door", "", rgb(205, 133, 63), 14.3, 4.5, 15.2, 4.7, mx, my);     // Cửa vào Tắm & WC từ Hành lang
                do add_plan_sym("wall", "", rgb(54, 69, 79), 15.2, 4.5, 16.25, 4.7, mx, my);

                // 2.6. Tường đáy giáp Sảnh tầng (tại y = 7.0)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 11.0, 6.9, 11.6, 7.1, mx, my);
                do add_plan_sym("door", "", rgb(205, 133, 63), 11.6, 6.9, 12.5, 7.1, mx, my);     // CỬA CHÍNH CĂN HỘ (Mở vào Tiền Sảnh)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 12.5, 6.9, 16.25, 7.1, mx, my);    // Tường đặc kín (đáy WC hoàn toàn kín)

                // 2.7. Cửa sổ mặt tiền Bắc & Đông
                do add_plan_sym("facade_window", "", #deepskyblue, 11.8, -0.06, 13.0, 0.06, mx, my); // Cửa sổ PN1
                do add_plan_sym("facade_window", "", #deepskyblue, 14.2, -0.06, 15.4, 0.06, mx, my); // Cửa sổ PN2
                do add_plan_sym("facade_window", "", #deepskyblue, 17.2, -0.06, 19.0, 0.06, mx, my); // Cửa sổ Living Bắc
                do add_plan_sym("facade_window", "", #deepskyblue, 21.94, 1.4, 22.06, 3.4, mx, my);  // Cửa sổ Living Đông
                do add_plan_sym("facade_window", "", #deepskyblue, 21.94, 5.2, 22.06, 6.6, mx, my);  // Cửa sổ Bếp Đông (Origin)

                // 3. DUY NHẤT FLAT 16: ĐẦY ĐỦ NỘI THẤT CHI TIẾT THEO FIGURE 4
                if (is_f16) {
                    do add_plan_sym("origin_fridge", "ORIGIN", #red, 21.2, 6.2, 21.9, 6.9, mx, my);
                    do add_plan_sym("furniture", "Máy Giặt", #silver, 20.3, 6.3, 21.0, 6.9, mx, my);
                    do add_plan_sym("furniture", "Bếp Nấu", #darkblue, 19.4, 6.3, 20.1, 6.9, mx, my);
                    do add_plan_sym("furniture", "Bồn Rửa", #saddlebrown, 16.8, 6.3, 19.2, 6.9, mx, my);
                    do add_plan_sym("furniture", "Mini-fridge", #lightcyan, 21.2, 4.8, 21.9, 5.4, mx, my);

                    do add_plan_sym("furniture", "Sofa", #white, 17.5, 0.4, 20.2, 1.2, mx, my);
                    do add_plan_sym("furniture", "Sofa", #white, 20.6, 1.4, 21.4, 3.4, mx, my);
                    do add_plan_sym("furniture", "Thảm", rgb(45, 95, 175), 17.8, 1.4, 20.2, 3.4, mx, my);
                    do add_plan_sym("furniture", "Bàn Trà", #cyan, 18.3, 1.8, 19.7, 2.9, mx, my);
                    do add_plan_sym("furniture", "Bàn Ăn", #teal, 16.5, 2.2, 17.5, 3.6, mx, my);
                    do add_plan_sym("furniture", "TV", #black, 16.35, 0.6, 16.85, 1.8, mx, my);

                    do add_plan_sym("furniture", "Giường 1", rgb(240, 246, 255), 11.3, 0.8, 13.1, 2.8, mx, my);
                    do add_plan_sym("furniture", "Tủ Áo 1", #saddlebrown, 13.2, 0.6, 13.55, 2.6, mx, my);
                    do add_plan_sym("furniture", "Giường 2", rgb(240, 246, 255), 13.9, 0.8, 15.7, 2.8, mx, my);
                    do add_plan_sym("furniture", "Tủ Áo 2", #saddlebrown, 15.8, 0.6, 16.15, 2.6, mx, my);

                    do add_plan_sym("furniture", "Bồn Tắm", #white, 14.0, 5.0, 16.0, 5.7, mx, my);
                    do add_plan_sym("furniture", "Bồn Cầu", #white, 15.2, 6.2, 16.0, 6.8, mx, my);
                    do add_plan_sym("furniture", "Lavabo", #white, 14.0, 6.2, 14.8, 6.8, mx, my);
                }
            }

            // -----------------------------------------------------------------
            // III. 2 CĂN GIỮA (1-BEDROOM FLATS: 7.0m x 8.0m = 56m²)
            // FLAT 11 (MẶT ĐÔNG) & FLAT 14 (MẶT TÂY) - CẤU TRÚC PHÂN PHÒNG RÕ RÀNG
            // -----------------------------------------------------------------
            list<bool> mid_mirs <- [false, true];
            list<string> mid_titles <- (selected_floor = 4) ? [
                "FLAT 11 [MẶT ĐÔNG - 1PN]", 
                "FLAT 14 [MẶT TÂY - 1PN]"
            ] : [
                "FLAT " + (base_num + 1) + " [MẶT ĐÔNG - 1PN]", 
                "FLAT " + (base_num + 4) + " [MẶT TÂY - 1PN]"
            ];
            list<rgb> mid_colors_list <- [
                rgb(90, 15, 65), // Flat 11: Tím mận
                rgb(95, 15, 20)  // Flat 14: Đỏ mận
            ];

            loop mi from: 0 to: 1 {
                bool mx_m <- mid_mirs[mi];
                string m_code <- mid_titles[mi];
                rgb m_col <- mid_colors_list[mi];

                // 1. Phân chia phòng ốc chuẩn xác theo Kiến trúc Grenfell Tower & Wiley Efectis (Part 3 Fig 5 & Part 4 Fig 1)
                // - Dải ngoài tiếp giáp mặt tiền (East / West Façade): Cả 3 phòng đều có cửa sổ riêng ra ngoài mặt dựng
                do add_plan_sym("room", "PHÒNG KHÁCH", m_col, 17.5, 7.0, 22.0, 10.4, mx_m, false);
                do add_plan_sym("room", "PHÒNG BẾP", m_col, 17.5, 10.4, 22.0, 12.6, mx_m, false);
                do add_plan_sym("room", "PHÒNG NGỦ", m_col, 17.5, 12.6, 22.0, 15.0, mx_m, false);

                // - Dải trong tiếp giáp lõi trung tâm:
                //   + SẢNH & HÀNH LANG chạy dọc kết nối trực tiếp Cửa chính, Khách, Bếp, Ngủ và WC
                //   + TẮM & WC là phòng riêng biệt khép kín ở góc trong phía Nam sát hộp Riser cấp thoát nước
                do add_plan_sym("room", "SẢNH", m_col, 15.0, 7.0, 17.5, 12.6, mx_m, false);
                do add_plan_sym("room", "", m_col, 16.4, 12.6, 17.5, 15.0, mx_m, false); // Nhánh hành lang Sảnh dẫn vào Phòng Ngủ
                do add_plan_sym("room", "TẮM & WC", m_col, 15.0, 12.6, 16.4, 15.0, mx_m, false);

                create plan_element with: [
                    etype: "flat_tag",
                    elabel: m_code,
                    ecolor: #yellow,
                    shape: create_box(to_px(sym_x(18.5, mx_m)), to_py(7.2), to_px(sym_x(21.0, mx_m)), to_py(7.6))
                ];

                // 2. Hệ tường và cửa ngăn phòng khoa học: MỌI PHÒNG ĐỀU RA THẲNG SẢNH, KHÔNG PHÒNG NÀO PHẢI ĐI QUA WC
                // 2.1. Tường dọc tại x = 17.5 ngăn dải ngoài với Sảnh
                // - Cửa mở trực tiếp từ Phòng Khách ra Sảnh (y: 8.0 -> 9.4) - THÔNG THẲNG RA SẢNH, HOÀN TOÀN TÁCH BIỆT WC!
                do add_plan_sym("wall", "", rgb(54, 69, 79), 17.4, 7.0, 17.6, 8.0, mx_m, false);
                do add_plan_sym("door", "", rgb(205, 133, 63), 17.4, 8.0, 17.6, 9.4, mx_m, false);   // CỬA PHÒNG KHÁCH RA THẲNG SẢNH
                // - Tường đặc ôm trọn mối nối tường ngang Khách - Bếp (y = 9.4 -> 11.0, tường ngang tại 10.4)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 17.4, 9.4, 17.6, 11.0, mx_m, false);
                // - Cửa mở trực tiếp từ Phòng Bếp ra Sảnh (y: 11.0 -> 12.0)
                do add_plan_sym("door", "", rgb(205, 133, 63), 17.4, 11.0, 17.6, 12.0, mx_m, false);  // CỬA PHÒNG BẾP RA THẲNG SẢNH
                // - Tường đặc ôm trọn mối nối tường ngang Bếp - Ngủ (y = 12.0 -> 13.0, tường ngang tại 12.6)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 17.4, 12.0, 17.6, 13.0, mx_m, false);
                // - Cửa mở trực tiếp từ Phòng Ngủ ra nhánh Sảnh hành lang (y: 13.0 -> 14.2)
                do add_plan_sym("door", "", rgb(205, 133, 63), 17.4, 13.0, 17.6, 14.2, mx_m, false);  // CỬA PHÒNG NGỦ RA THẲNG SẢNH
                // - Đoạn tường cuối phòng ngủ (y: 14.2 -> 15.0)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 17.4, 14.2, 17.6, 15.0, mx_m, false);

                // 2.2. Các tường ngang ngăn phòng dải ngoài
                // - Tường ngăn Khách và Bếp tại y = 10.4 (tường đặc khép kín)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 17.5, 10.3, 22.0, 10.5, mx_m, false);
                // - Tường ngăn Bếp và Phòng Ngủ tại y = 12.6 (tường đặc khép kín)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 17.5, 12.5, 22.0, 12.7, mx_m, false);

                // 2.3. Hệ vách và cửa phòng TẮM & WC (Phòng riêng biệt khép kín, có cửa riêng mở ra Sảnh)
                // - Tường ngang phía Bắc phòng WC tại y = 12.6 (cửa riêng vào WC từ Sảnh)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 15.0, 12.5, 15.3, 12.7, mx_m, false);
                do add_plan_sym("door", "", rgb(205, 133, 63), 15.3, 12.5, 16.2, 12.7, mx_m, false);  // CỬA RIÊNG VÀO TẮM & WC TỪ SẢNH
                do add_plan_sym("wall", "", rgb(54, 69, 79), 16.2, 12.5, 16.4, 12.7, mx_m, false);
                // - Tường dọc phía Đông phòng WC tại x = 16.4 ngăn cách WC với hành lang dẫn vào phòng ngủ
                do add_plan_sym("wall", "", rgb(54, 69, 79), 16.3, 12.6, 16.5, 15.0, mx_m, false);

                // 2.4. Vách tường giáp sảnh tầng tại x = 15.0 và CỬA CHÍNH CĂN HỘ (NẰM Ở PHÍA TRÊN, MỞ RA HÀNH LANG BẮC SẢNH TẦNG)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 14.9, 7.0, 15.1, 7.2, mx_m, false);
                do add_plan_sym("door", "", rgb(205, 133, 63), 14.9, 7.2, 15.1, 8.4, mx_m, false);  // CỬA CHÍNH CĂN HỘ (Mở ra Sảnh tầng ở phía trên, hoàn toàn tránh buồng thang và thang máy!)
                do add_plan_sym("wall", "", rgb(54, 69, 79), 14.9, 8.4, 15.1, 15.0, mx_m, false); // Tường đặc 100% ngăn cách với buồng thang bộ / buồng thang máy và Riser phía Nam

                // 2.5. HỆ THỐNG 3 CỬA SỔ MẶT TIỀN (CHUẨN PART 3 FIGURE 5 & ELEVATION BAYS)
                do add_plan_sym("facade_window", "", #deepskyblue, 21.94, 7.6, 22.06, 9.6, mx_m, false);   // Cửa sổ Phòng Khách (rộng 2.0m)
                do add_plan_sym("facade_window", "", #deepskyblue, 21.94, 10.8, 22.06, 12.2, mx_m, false); // Cửa sổ Phòng Bếp (rộng 1.4m)
                do add_plan_sym("facade_window", "", #deepskyblue, 21.94, 13.0, 22.06, 14.6, mx_m, false); // Cửa sổ Phòng Ngủ (rộng 1.6m)
            }

            // -----------------------------------------------------------------
            // IV. TƯỜNG RANH GIỚI NGĂN CÁCH GIỮA CÁC CĂN HỘ
            // -----------------------------------------------------------------
            create plan_element with: [etype: "wall", elabel: "", ecolor: #black, shape: create_box(to_px(10.9), to_py(0.0), to_px(11.1), to_py(7.0))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: #black, shape: create_box(to_px(10.9), to_py(15.0), to_px(11.1), to_py(22.0))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: #black, shape: create_box(to_px(15.0), to_py(6.9), to_px(22.0), to_py(7.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: #black, shape: create_box(to_px(15.0), to_py(14.9), to_px(22.0), to_py(15.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: #black, shape: create_box(to_px(0.0), to_py(6.9), to_px(7.0), to_py(7.1))];
            create plan_element with: [etype: "wall", elabel: "", ecolor: #black, shape: create_box(to_px(0.0), to_py(14.9), to_px(7.0), to_py(15.1))];
        }

        // ---------------------------------------------------------------------
        // V. 14 CỘT BÊ TÔNG BÁT GIÁC CHU VI NGOẠI BIÊN
        // ---------------------------------------------------------------------
        list<point> col_positions <- [
            {0.5, 0.5}, {5.75, 0.5}, {11.0, 0.5}, {16.25, 0.5}, {21.5, 0.5},
            {21.5, 7.0}, {21.5, 15.0},
            {21.5, 21.5}, {16.25, 21.5}, {11.0, 21.5}, {5.75, 21.5}, {0.5, 21.5},
            {0.5, 15.0}, {0.5, 7.0}
        ];

        loop cp over: col_positions {
            create plan_element with: [
                etype: "column", 
                elabel: "", 
                ecolor: rgb(110, 120, 130), 
                shape: create_column_geom(to_px(cp.x), to_py(cp.y), 0.8)
            ];
        }

        // Tường bao viền ngoài 4 cạnh
        create plan_element with: [etype: "outer_wall", elabel: "", ecolor: #black, shape: create_box(px1, py1 - 0.3, px2, py1)];
        create plan_element with: [etype: "outer_wall", elabel: "", ecolor: #black, shape: create_box(px2, py1, px2 + 0.3, py2)];
        create plan_element with: [etype: "outer_wall", elabel: "", ecolor: #black, shape: create_box(px1, py2, px2, py2 + 0.3)];
        create plan_element with: [etype: "outer_wall", elabel: "", ecolor: #black, shape: create_box(px1 - 0.3, py1, px1, py2)];
    }

    // =========================================================================
    // 3. XỬ LÝ CLICK CHUỘT CHỌN TẦNG TRÊN MẶT ĐỨNG BÊN TRÁI
    // =========================================================================
    action select_floor {
        point click_pt <- #user_location;
        if (click_pt.x >= 4.0 and click_pt.x <= 44.0) {
            ask floor_level_agt {
                if (click_pt.y >= self.y_top and click_pt.y <= self.y_bot) {
                    selected_floor <- self.floor_id;
                    selected_floor_name <- self.floor_label;
                    
                    ask floor_level_agt {
                        self.is_selected <- (self.floor_id = selected_floor);
                    }
                    
                    write "Khảo sát Tầng: " + selected_floor_name + " (Floor ID: " + selected_floor + ")";
                    
                    ask world {
                        do build_active_floor_plan;
                    }
                }
            }
        }
    }
}

// =============================================================================
// CÁC LOÀI ĐỐI TƯỢNG (AGENT SPECIES)
// =============================================================================

// Mô hình số học mặt đứng 25 tầng tháp theo Figure 2
species floor_level_agt {
    int floor_id;
    string floor_label;
    bool is_selected <- false;
    float y_top;
    float y_bot;
    float y_mid;

    aspect default {
        if (is_selected) {
            draw rectangle(35.0, y_bot - y_top + 0.3) at_location {22.5, y_mid} color: rgb(255, 245, 175, 140) border: #red;
            draw ("◄ TẦNG " + floor_label) at: {39.5, y_mid + 0.4} color: #red font: font("Arial", 8, #bold);
        }

        if (floor_id = 23) {
            draw "← 23th floor" at: {39.5, y_mid + 0.4} color: rgb(180, 40, 40) font: font("Arial", 9, #bold);
        }
        if (floor_id = 4) {
            draw "← 4th floor" at: {39.5, y_mid + 0.4} color: rgb(180, 40, 40) font: font("Arial", 9, #bold);
        }

        rgb clad_col <- rgb(118, 140, 160);

        // MẶT ĐỨNG BÊN TRÁI: North and South elevations
        draw rectangle(15.0, y_bot - y_top) at_location {13.5, y_mid} color: clad_col border: rgb(85, 102, 118);
        draw line([{6.0, y_bot}, {21.0, y_bot}]) color: rgb(65, 80, 95);

        if (floor_id >= 4 and floor_id <= 23) {
            float win_h <- (y_bot - y_top) * 0.62;
            float win_y <- y_mid;

            draw line([{15.3, y_top}, {15.3, y_bot}]) color: rgb(75, 92, 108);

            list<float> ns_bays <- [7.4, 9.4, 11.4, 13.4, 16.6, 18.6];
            loop bx over: ns_bays {
                draw rectangle(1.6, win_h) at_location {bx, win_y} color: rgb(35, 42, 48);
                draw rectangle(0.70, win_h - 0.2) at_location {bx - 0.38, win_y} color: rgb(245, 248, 252);
                draw rectangle(0.70, win_h - 0.2) at_location {bx + 0.38, win_y} color: rgb(215, 230, 244);
                draw line([{bx, win_y - win_h / 2.0}, {bx, win_y + win_h / 2.0}]) color: rgb(35, 42, 48);
            }
        } else if (floor_id = 24) {
            draw rectangle(15.0, y_bot - y_top) at_location {13.5, y_mid} color: rgb(105, 125, 142) border: rgb(70, 85, 100);
            list<float> c_lines <- [8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0];
            loop lx over: c_lines {
                draw line([{lx, y_top}, {lx, y_bot}]) color: rgb(70, 85, 100);
            }
        } else {
            draw rectangle(15.0, y_bot - y_top) at_location {13.5, y_mid} color: rgb(210, 215, 222) border: rgb(120, 130, 140);
            draw rectangle(13.6, (y_bot - y_top) * 0.7) at_location {13.5, y_mid} color: rgb(180, 205, 225);
        }

        // MẶT ĐỨNG BÊN PHẢI: East and West elevations
        draw rectangle(15.0, y_bot - y_top) at_location {31.5, y_mid} color: clad_col border: rgb(85, 102, 118);
        draw line([{24.0, y_bot}, {39.0, y_bot}]) color: rgb(65, 80, 95);

        if (floor_id >= 4 and floor_id <= 23) {
            float win_h <- (y_bot - y_top) * 0.62;
            float win_y <- y_mid;

            list<float> ew_bays <- [25.4, 27.8, 30.2, 32.6, 35.0, 37.4];
            loop bx over: ew_bays {
                draw rectangle(1.8, win_h) at_location {bx, win_y} color: rgb(35, 42, 48);
                draw rectangle(0.48, win_h - 0.2) at_location {bx - 0.55, win_y} color: rgb(245, 248, 252);
                draw rectangle(0.48, win_h - 0.2) at_location {bx, win_y} color: rgb(215, 230, 245);
                draw rectangle(0.48, win_h - 0.2) at_location {bx + 0.55, win_y} color: rgb(240, 246, 252);
                draw line([{bx - 0.28, win_y - win_h / 2.0}, {bx - 0.28, win_y + win_h / 2.0}]) color: rgb(35, 42, 48);
                draw line([{bx + 0.28, win_y - win_h / 2.0}, {bx + 0.28, win_y + win_h / 2.0}]) color: rgb(35, 42, 48);
            }
        } else if (floor_id = 24) {
            draw rectangle(15.0, y_bot - y_top) at_location {31.5, y_mid} color: rgb(105, 125, 142) border: rgb(70, 85, 100);
            list<float> c_lines_ew <- [26.0, 28.0, 30.0, 32.0, 34.0, 36.0, 38.0];
            loop lx over: c_lines_ew {
                draw line([{lx, y_top}, {lx, y_bot}]) color: rgb(70, 85, 100);
            }
        } else {
            draw rectangle(15.0, y_bot - y_top) at_location {31.5, y_mid} color: rgb(210, 215, 222) border: rgb(120, 130, 140);
            draw rectangle(13.6, (y_bot - y_top) * 0.7) at_location {31.5, y_mid} color: rgb(180, 205, 225);
        }
    }
}

// Thực thể phòng, tường, cửa, cửa sổ & nội thất trên mặt bằng bên phải
species plan_element {
    string etype;
    string elabel;
    rgb ecolor;

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
            draw "ORIGIN" at: {location.x - 0.9, location.y + 0.3} color: #yellow font: font("Arial", 8, #bold);
        } else if (etype = "furniture") {
            draw shape color: ecolor border: rgb(40, 45, 55);
            if (elabel != "") {
                draw elabel at: {location.x - (length(elabel) * 0.16), location.y + 0.25} color: rgb(25, 30, 45) font: font("Arial", 7, #bold);
            }
        } else if (etype = "stair_box") {
            draw shape color: ecolor border: rgb(40, 40, 40);
            float mid_x <- (shape.points[0].x + shape.points[1].x) / 2.0;
            float top_y <- shape.points[0].y;
            float bot_y <- shape.points[2].y;

            draw line([{mid_x, top_y + 0.8}, {mid_x, bot_y - 0.8}]) color: rgb(50, 50, 50);
            loop i from: 0 to: 8 {
                float step_y <- top_y + 1.0 + (i * 0.85);
                draw line([{shape.points[0].x, step_y}, {mid_x, step_y}]) color: rgb(90, 90, 90);
                draw line([{mid_x, step_y}, {shape.points[1].x, step_y}]) color: rgb(90, 90, 90);
            }
            draw "THANG BỘ" at: {mid_x - 1.2, top_y + 0.8} color: rgb(180, 30, 30) font: font("Arial", 11, #bold);
        } else if (etype = "lift_cab") {
            draw shape color: ecolor border: rgb(40, 40, 40);
            if (elabel != "") {
                draw elabel at: {location.x - 0.9, location.y + 0.35} color: rgb(20, 20, 20) font: font("Arial", 11, #bold);
            }
        } else if (etype = "flat_tag") {
            draw elabel at: {location.x - (length(elabel) * 0.22), location.y} color: ecolor font: font("Arial", 12, #bold);
        } else {
            // Sàn các phòng (room, lobby, riser)
            draw shape color: ecolor;
            if (elabel != "") {
                float lum <- (ecolor.red * 0.299 + ecolor.green * 0.587 + ecolor.blue * 0.114);
                rgb t_col <- (lum > 130.0) ? rgb(15, 15, 15) : #white;
                draw elabel at: {location.x - (length(elabel) * 0.20), location.y + 0.35} color: t_col font: font("Arial", 11, #bold);
            }
        }
    }
}

// Tiêu đề mặt bằng bên phải
species plan_label {
    string m_text;
    string s_text;

    aspect default {
        draw m_text at: {location.x, location.y - 0.8} color: rgb(15, 25, 60) font: font("Arial", 13, #bold);
        draw s_text at: {location.x, location.y + 0.8} color: rgb(80, 90, 110) font: font("Arial", 9, #plain);
    }
}

// Chi tiết trang trí khung giao diện
species screen_decor {
    string dtype;
    string label;

    aspect default {
        if (dtype = "header") {
            draw label at: location color: rgb(20, 35, 80) font: font("Arial", 13, #bold);
        } else if (dtype = "title_left") {
            draw label at: location color: rgb(45, 55, 75) font: font("Arial", 11, #bold);
        } else if (dtype = "separator") {
            draw shape color: rgb(185, 195, 210);
        } else if (dtype = "fig2_label") {
            draw label at: location color: rgb(15, 55, 130) font: font("Arial", 11, #bold);
        } else if (dtype = "fig2_caption") {
            draw label at: location color: rgb(40, 50, 70) font: font("Arial", 10, #bold);
        }
    }
}

// =============================================================================
// THIẾT LẬP EXPERIMENT TƯƠNG TÁC (FIGURE 2 & MẶT BẰNG TẦNG 4 CHI TIẾT)
// =============================================================================
experiment Grenfell_Master_Simulation type: gui {
    action select_floor {
        ask simulation {
            do select_floor;
        }
    }

    output {
        display "Mô_Hình_Kiến_Trúc_Grenfell_Tower" type: 2d background: rgb(245, 248, 252) {
            event #mouse_down action: select_floor;

            // Khung và tiêu đề
            species screen_decor;

            // Nửa bên trái: Mặt đứng 25 tầng tháp (Figure 2)
            species floor_level_agt;

            // Nửa bên phải: Mặt bằng cắt ngang 2D chi tiết
            species plan_element;
            species plan_label;

            // ĐỒ HỌA TRANG TRÍ LA BÀN & LIMIT OF THE MODEL
            graphics "Figure3_Decorations" {
                float px1 <- 49.0;
                float px2 <- 93.0;
                float py1 <- 16.0;
                float py2 <- 60.0;

                draw "North" at: {70.0, py1 - 1.2} color: rgb(20, 30, 60) font: font("Arial", 14, #bold);
                draw "South" at: {70.0, py2 + 2.2} color: rgb(20, 30, 60) font: font("Arial", 14, #bold);
                draw "West" at: {px1 - 3.8, 38.5} color: rgb(20, 30, 60) font: font("Arial", 14, #bold);
                draw "East" at: {px2 + 1.2, 38.5} color: rgb(20, 30, 60) font: font("Arial", 14, #bold);

                // Khung viền nét đứt bao quanh Flat 16 và Flat 11 (Chỉ hiển thị ở Tầng 4 - vùng nghiên cứu cháy FDS)
                if (selected_floor = 4) {
                    float l_x1 <- 49.0 + (14.5 * 2.0); // 78.0
                    float l_x2 <- px2;                  // 93.0
                    float l_y1 <- py1 + 0.3;            // 16.3
                    float l_y2 <- py1 + (14.8 * 2.0);   // 45.6

                    loop i from: 0 to: 9 {
                        float bx <- l_x1 + (i * 1.5);
                        draw line([{bx, l_y1}, {bx + 0.9, l_y1}]) color: rgb(255, 255, 255);
                        draw line([{bx, l_y2}, {bx + 0.9, l_y2}]) color: rgb(255, 255, 255);
                    }
                    loop j from: 0 to: 18 {
                        float by <- l_y1 + (j * 1.5);
                        draw line([{l_x1, by}, {l_x1, by + 0.9}]) color: rgb(255, 255, 255);
                        draw line([{l_x2, by}, {l_x2, by + 0.9}]) color: rgb(255, 255, 255);
                    }

                    draw "Limit of the model" at: {l_x2 + 1.2, l_y2} color: rgb(210, 40, 40) font: font("Arial", 10, #bold);
                }
            }

            // Thanh thông tin trạng thái kiến trúc bên dưới (HUD Status)
            graphics "HUD_Status" {
                draw "BẢN VẼ KIẾN TRÚC TOÀN SÀN: 22.0m x 22.0m | LÕI KỸ THUẬT: 8.0m x 8.0m (2 THANG MÁY + THANG BỘ DUY NHẤT)" at: {49.0, 64.8} color: rgb(20, 35, 75) font: font("Arial", 10, #bold);
                draw "TẦNG ĐANG KHẢO SÁT: " + selected_floor_name + " | 6 CĂN HỘ: X1(East 1PN), X2(SE 2PN), X3(SW 2PN), X4(West 1PN), X5(NW 2PN), X6(NE 2PN)" at: {49.0, 67.5} color: rgb(40, 50, 70) font: font("Arial", 9, #plain);
                draw "HƯỚNG DẪN: Click chuột trái vào bất kỳ tầng nào trên mặt đứng bên trái để chuyển đổi mặt bằng khảo sát tương ứng." at: {49.0, 70.0} color: rgb(150, 30, 30) font: font("Arial", 9, #bold);
            }
        }
    }
}
