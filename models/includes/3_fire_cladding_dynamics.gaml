/**
 * Module: 3_fire_cladding_dynamics.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: MODULE LỬA & KHÓI — DUAL-LAYER MULTI-FLOOR SYNCHRONIZED SIMULATION
 *
 *   1. ĐỒNG BỘ TỌA ĐỘ PHÁT TÁN (ALIGNED VERTICAL PLUME):
 *      - Đám cháy ở các tầng trên XUẤT PHÁT TẠI ĐÚNG VỊ TRÍ CỬA SỔ THẲNG HÀNG VỚI NGUỒN CHÁY TẦNG DƯỚI.
 *      - Không phát tán từ toàn bộ mặt tường 22m.
 *
 *   2. ĐỘ TRỄ LAN TRUYỀN PHÙ HỢP (REALISTIC VERTICAL DELAY):
 *      - Độ trễ nhịp nhàng (~3.5 giây mỗi tầng) khi lửa liếm theo dải Cladding mặt ngoài.
 *
 *   3. MÔ PHỎNG CHÁY NỀN ĐA TẦNG ĐỘC LẬP (MULTI-FLOOR BACKGROUND SIMULATION):
 *      - Tất cả các tầng đã bắt lửa đều tiếp tục diễn biến cháy và sinh khói ngầm trong nền theo thời gian thực.
 *      - Dữ liệu được lưu trong bộ đệm Floor Buffer độc lập (floor_burning_cells, floor_smoky_cells).
 *      - Khi người dùng chuyển sang bất kỳ tầng nào: Snapshot được lưu/nạp tức thì mà không bị reset và không gây lag CPU!
 *
 *   Tương thích GAMA 2025.6.4
 */

model fire_cladding_dynamics

import "2_grid_rasterizer.gaml"

global {
    // =========================================================================
    // THAM SỐ THỜI GIAN & LAN TRUYỀN MẶT BẰNG 2D
    // =========================================================================
    float step <- 0.1 #s;

    // Hướng gió tự nhiên (thổi lệch hướng Bắc - Tây Bắc)
    point wind_direction <- {0.2, -1.0};

    // Xác suất lan truyền vi mô trên mặt bằng
    float fire_spread_probability  <- 0.035;  // Xác suất lửa bén ô lân cận
    float smoke_spread_probability <- 0.14;   // Xác suất khói lan ô lân cận
    float smoke_decay              <- 0.005;  // Suy giảm nồng độ khói
    float fire_growth_rate         <- 0.02;   // Tăng cường độ lửa

    // Điều khiển trạng thái toàn cục
    bool  fire_started       <- false; // Đã click đặt lửa trong phòng
    bool  cladding_ignited   <- false; // Lửa đã chạm cửa sổ -> Cladding mặt đứng bắt đầu cháy
    int   sim_ticks          <- 0;
    int   fire_phase         <- 0;     // 0: Chưa cháy, 1: Cháy trong phòng, 2: Cladding leo đứng, 3: Crown & Chữ V

    // Tọa độ điểm xuất phát cháy ban đầu (để dóng thẳng trục đứng cho các tầng trên)
    point fire_origin_loc    <- {91.5, 22.5}; // Mặc định vị trí bếp Flat 16 phía Đông

    // Điều khiển lan truyền mặt đứng có độ trễ hợp lý
    int   highest_east_floor <- 4;
    int   v_lowest_floor     <- 24;
    bool  crown_reached      <- false;
    int   vertical_interval  <- 35;    // 35 ticks (~3.5 giây) mỗi tầng, tạo độ trễ nhịp nhàng tự nhiên

    // =========================================================================
    // A. BỘ ĐỆM ĐA TẦNG: LƯU & NẠP SNAPSHOT TẾ BÀO LƯỚI KHI ĐỔI TẦNG (NO LAG)
    // =========================================================================

    // Lưu snapshot tầng đang hiển thị vào floor_level_agt
    action save_current_floor_state {
        floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
        if (cur_fl = nil) { return; }

        list<grid_cell> b_cells <- floor_interior_cells where (each.burning);
        list<grid_cell> s_cells <- floor_interior_cells where (each.smoky);

        list<int> b_indices <- [];
        map<int, float> f_pow <- [];
        loop c over: b_cells {
            b_indices <- b_indices + [c.cell_id];
            f_pow[c.cell_id] <- c.fire_power;
        }

        list<int> s_indices <- [];
        map<int, float> s_dens <- [];
        loop c over: s_cells {
            s_indices <- s_indices + [c.cell_id];
            s_dens[c.cell_id] <- c.smoke_density;
        }

        cur_fl.floor_burning_cells     <- b_indices;
        cur_fl.floor_fire_power        <- f_pow;
        cur_fl.floor_smoky_cells       <- s_indices;
        cur_fl.floor_smoke_density_map <- s_dens;
    }

    // Nạp snapshot từ floor_level_agt lên lưới grid_cell
    action restore_active_floor_state {
        floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
        if (cur_fl = nil) { return; }

        // Xóa trắng trạng thái lửa/khói trên mặt bằng hiện tại
        ask floor_interior_cells {
            self.burning       <- false;
            self.fire_power    <- 0.0;
            self.smoky         <- false;
            self.smoke_density <- 0.0;
            self.color         <- #transparent;
        }

        // Nếu tầng này chưa bắt lửa -> giữ nguyên mặt bằng sạch
        if (cur_fl.fire_start_tick = -1 and empty(cur_fl.floor_burning_cells)) {
            return;
        }

        // Phục hồi các ô khói
        loop sid over: cur_fl.floor_smoky_cells {
            grid_cell cell <- grid_cell(sid);
            if (cell != nil and !cell.is_obstacle) {
                cell.smoky         <- true;
                cell.smoke_density <- cur_fl.floor_smoke_density_map contains_key sid ? cur_fl.floor_smoke_density_map[sid] : 0.5;
                int g_val <- int(230 - (cell.smoke_density * 170));
                cell.color <- rgb(g_val, g_val, g_val, 185);
            }
        }

        // Phục hồi các ô lửa
        loop bid over: cur_fl.floor_burning_cells {
            grid_cell cell <- grid_cell(bid);
            if (cell != nil and !cell.is_obstacle) {
                cell.burning       <- true;
                cell.fire_power    <- cur_fl.floor_fire_power contains_key bid ? cur_fl.floor_fire_power[bid] : 0.8;
                cell.smoky         <- true;
                cell.smoke_density <- 1.0;
                int r_val <- 255;
                int g_val <- int(160 * (1.0 - cell.fire_power));
                cell.color <- rgb(r_val, g_val, 0, 225);
            }
        }
    }

    // Khởi tạo mầm lửa/khói đầu tiên cho một tầng khi bị bứt phá vỡ cửa sổ từ ngoài mặt đứng
    action ignite_floor_interior_entry(int f_id) {
        floor_level_agt fl <- first(floor_level_agt where (each.floor_id = f_id));
        if (fl = nil or fl.floor_initialized_fire) { return; }

        fl.floor_initialized_fire <- true;
        fl.interior_fire          <- true;
        fl.window_broken          <- true;
        fl.fire_start_tick        <- sim_ticks;

        // Vị trí trục cửa sổ đón lửa từ ngoài mặt đứng phía Đông (dóng theo Y của điểm cháy ban đầu)
        point entry_point <- {93.0, fire_origin_loc.y};
        list<grid_cell> entry_cells <- floor_open_cells where (each.location distance_to entry_point <= 2.8);

        if (empty(entry_cells)) {
            entry_cells <- [floor_open_cells closest_to entry_point];
        }

        list<int> b_idx <- [];
        map<int, float> f_pow <- [];
        list<int> s_idx <- [];
        map<int, float> s_dens <- [];

        loop c over: entry_cells {
            b_idx <- b_idx + [c.cell_id];
            f_pow[c.cell_id] <- 0.8;
            s_idx <- s_idx + [c.cell_id];
            s_dens[c.cell_id] <- 0.9;
        }

        fl.floor_burning_cells     <- b_idx;
        fl.floor_fire_power        <- f_pow;
        fl.floor_smoky_cells       <- s_idx;
        fl.floor_smoke_density_map <- s_dens;

        // Nếu tầng này đang là tầng hiển thị trên màn hình, nạp ngay lập tức lên grid_cell
        if (f_id = selected_floor) {
            do restore_active_floor_state;
        }
    }

    // =========================================================================
    // 1. CLICK CHUỘT: ĐẶT ĐIỂM CHÁY TẠI VỊ TRÍ BẤT KỲ TRÊN MẶT BẰNG
    // =========================================================================
    action place_fire_at_click {
        point click_loc <- #user_location;

        if (click_loc.x < 49.0 or click_loc.x > 93.0 or click_loc.y < 16.0 or click_loc.y > 60.0) {
            write "[Fire] Vui lòng Click bên trong phạm vi mặt bằng tòa nhà (bên phải)!";
            return;
        }

        grid_cell target_cell <- grid_cell closest_to click_loc;
        if (target_cell = nil or target_cell.is_obstacle) {
            write "[Fire] Không thể đặt lửa lên tường / cột / vật cản!";
            return;
        }

        fire_origin_loc <- click_loc;
        fire_started    <- true;
        sim_ticks       <- 0;
        fire_phase      <- 1;

        ask target_cell {
            burning       <- true;
            fire_power    <- 1.0;
            smoky         <- true;
            smoke_density <- 1.0;
            color         <- #red;
        }

        floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
        if (cur_fl != nil) {
            cur_fl.interior_fire          <- true;
            cur_fl.fire_start_tick        <- 0;
            cur_fl.floor_initialized_fire <- true;
            cur_fl.floor_smoke_density    <- 0.4;
            // Lưu lại điểm cháy vào buffer tầng đang chọn
            cur_fl.floor_burning_cells     <- [target_cell.cell_id];
            cur_fl.floor_fire_power        <- [target_cell.cell_id::1.0];
            cur_fl.floor_smoky_cells       <- [target_cell.cell_id];
            cur_fl.floor_smoke_density_map <- [target_cell.cell_id::1.0];
        }

        write "==================================================================";
        write ">>> [BƯỚC 1: KHỞI PHÁT] Đã đặt điểm cháy tại: " + click_loc + " (Tầng " + selected_floor + ")!";
        write ">>> Ngọn lửa và khói đang bắt đầu lan từ từ trong phòng...";
        write ">>> (Mặt đứng bên trái chưa cháy cho đến khi ngọn lửa lan chạm tới mép cửa sổ ngoài)";
        write "==================================================================";
    }

    // =========================================================================
    // 2. REFLEX KIỂM TRA LỬA LAN TỚI CỬA SỔ NGOÀI (BREAKOUT CHECK)
    // =========================================================================
    reflex check_window_breakout when: (fire_started and !cladding_ignited) {
        list<grid_cell> burning_windows <- floor_interior_cells where (each.is_window and each.burning);

        if (!empty(burning_windows)) {
            cladding_ignited   <- true;
            fire_phase         <- 2;
            highest_east_floor <- selected_floor;

            grid_cell first_win <- first(burning_windows);
            if (first_win != nil) {
                fire_origin_loc <- first_win.location;
            }

            floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
            if (cur_fl != nil) {
                cur_fl.window_broken       <- true;
                cur_fl.clad_east           <- 0.6;
                cur_fl.floor_smoke_density <- 0.7;
            }

            write "==================================================================";
            write ">>> [BƯỚC 2: BỨT PHÁ VỠ CỬA SỔ] Lửa trong phòng đã lan chạm mép cửa sổ!";
            write ">>> Cửa sổ vỡ vụn! Lửa táp ra dải Cladding mặt ngoài và bắt đầu nung nóng để lan lên trên!";
            write "==================================================================";
        }
    }

    // =========================================================================
    // 3. REFLEX TIẾN TRÌNH LAN TRUYỀN CLADDING MẶT ĐỨNG 25 TẦNG
    //    Có độ trễ 3.5 giây mỗi tầng (vertical_interval = 35) rất nhịp nhàng
    // =========================================================================
    reflex cladding_vertical_controller when: cladding_ignited {
        // GIAI ĐOẠN 1: LAN THẲNG ĐỨNG TRÊN MẶT ĐÔNG LÊN ĐẾN TẦNG 24 (CROWN)
        if (!crown_reached) {
            if (sim_ticks mod vertical_interval = 0) {
                if (highest_east_floor < 24) {
                    highest_east_floor <- highest_east_floor + 1;
                    floor_level_agt next_fl <- first(floor_level_agt where (each.floor_id = highest_east_floor));
                    if (next_fl != nil) {
                        next_fl.clad_east           <- 0.6;
                        next_fl.floor_smoke_density <- 0.7;
                        // Kích hoạt bứt phá cháy nội thất ngầm cho tầng này
                        do ignite_floor_interior_entry(highest_east_floor);
                    }
                    write ">>> [CLADDING MẶT ĐÔNG] Lửa lan thẳng đứng lên TẦNG " + highest_east_floor;

                    if (highest_east_floor = 24) {
                        crown_reached <- true;
                        fire_phase    <- 3;
                        write "==================================================================";
                        write ">>> [CROWN] LỬA ĐÃ LAN ĐẾN ĐỈNH SÂN THƯỢNG (TẦNG 24 CROWN)!";
                        write "==================================================================";
                    }
                }
            }
        }

        // GIAI ĐOẠN 2: LAN ĐỈNH CROWN VÀ PHÁT TRIỂN CHỮ V NGƯỢC XUỐNG BẮC/NAM/TÂY
        if (crown_reached) {
            floor_level_agt f24 <- first(floor_level_agt where (each.floor_id = 24));
            if (f24 != nil) {
                if (f24.clad_north <= 0.1) { f24.clad_north <- 0.6; }
                if (f24.clad_south <= 0.1) { f24.clad_south <- 0.6; }
            }

            if (sim_ticks mod vertical_interval = 0) {
                if (v_lowest_floor > 4) {
                    v_lowest_floor <- v_lowest_floor - 1;
                    floor_level_agt down_fl <- first(floor_level_agt where (each.floor_id = v_lowest_floor));
                    if (down_fl != nil) {
                        down_fl.clad_north          <- 0.6;
                        down_fl.clad_south          <- 0.6;
                        down_fl.clad_west           <- 0.5;
                        down_fl.floor_smoke_density <- 0.8;
                        // Kích hoạt bứt phá cháy nội thất ngầm cho tầng này nếu chưa cháy
                        if (!down_fl.floor_initialized_fire) {
                            do ignite_floor_interior_entry(v_lowest_floor);
                        }
                    }
                    write ">>> [CHỮ V NGƯỢC] Lửa lan xuống TẦNG " + v_lowest_floor + " (mặt Bắc, Nam & Tây)!";
                }
            }
        }

        // GIAI ĐOẠN 3: TĂNG CƯỜNG ĐỘ & CHUYỂN DẦN SANG CHÁY KIỆT (THAN HÓA > 1.5)
        ask floor_level_agt {
            if (clad_east  > 0.1) { clad_east  <- min([2.0, clad_east  + 0.0015]); }
            if (clad_north > 0.1) { clad_north <- min([2.0, clad_north + 0.0015]); }
            if (clad_south > 0.1) { clad_south <- min([2.0, clad_south + 0.0015]); }
            if (clad_west  > 0.1) { clad_west  <- min([2.0, clad_west  + 0.0015]); }
        }
    }

    // =========================================================================
    // 4. REFLEX TIẾN TRÌNH LAN TRUYỀN TRONG NỀN CHO CÁC TẦNG KHÔNG HIỂN THỊ
    //    Cập nhật ngầm (Background CA) mỗi 3 ticks (~0.3s) cho CẢ LỬA VÀ KHÓI
    // =========================================================================
    reflex background_floors_simulation when: fire_started and (sim_ticks mod 3 = 0) {
        list<floor_level_agt> bg_floors <- floor_level_agt where (each.floor_id != selected_floor and (!empty(each.floor_burning_cells) or !empty(each.floor_smoky_cells)));

        loop fl over: bg_floors {
            list<int> cur_burning <- fl.floor_burning_cells;
            list<int> new_burning <- cur_burning;
            list<int> cur_smoky   <- fl.floor_smoky_cells;
            list<int> new_smoky   <- cur_smoky;

            // 1. Lan LỬA ngầm từ các ô đang cháy
            loop bid over: cur_burning {
                grid_cell c <- grid_cell(bid);
                if (c != nil) {
                    list<grid_cell> nb_open <- c.neighbors where (!each.is_obstacle);
                    loop nb over: nb_open {
                        if (!(new_burning contains nb.cell_id)) {
                            if (rnd(1.0) < (fire_spread_probability * 2.0)) {
                                new_burning <- new_burning + [nb.cell_id];
                                fl.floor_fire_power[nb.cell_id] <- 0.75;
                                if (!(new_smoky contains nb.cell_id)) {
                                    new_smoky <- new_smoky + [nb.cell_id];
                                    fl.floor_smoke_density_map[nb.cell_id] <- 1.0;
                                }
                            }
                        }
                    }
                }
            }

            // 2. Lan KHÓI ngầm từ TẤT CẢ CÁC Ô KHÓI (Khói lan nhanh và độc lập với biên lửa!)
            loop sid over: cur_smoky {
                grid_cell sc <- grid_cell(sid);
                if (sc != nil) {
                    float cur_density <- fl.floor_smoke_density_map contains_key sid ? fl.floor_smoke_density_map[sid] : 0.6;
                    list<grid_cell> nb_open <- sc.neighbors where (!each.is_obstacle);
                    loop nb over: nb_open {
                        if (!(new_smoky contains nb.cell_id)) {
                            // Khói lan rộng ra phía trước đám cháy
                            if (rnd(1.0) < (smoke_spread_probability * 2.2)) {
                                new_smoky <- new_smoky + [nb.cell_id];
                                fl.floor_smoke_density_map[nb.cell_id] <- max([0.3, cur_density * 0.85]);
                            }
                        }
                    }
                }
            }

            fl.floor_burning_cells <- new_burning;
            fl.floor_smoky_cells   <- new_smoky;
        }
    }

    // =========================================================================
    // 5. REFLEX LAN KHÓI TRÊN MẶT BẰNG 2D HIỂN THỊ (FOREGROUND SPREAD)
    // =========================================================================
    reflex spread_smoke when: fire_started {
        float wind_mag <- norm(wind_direction);
        point norm_wind <- (wind_mag = 0.0) ? {0.0, 0.0} : (wind_direction / wind_mag);

        ask floor_interior_cells where (each.smoky) {
            point src_loc     <- self.location;
            float src_density <- self.smoke_density;

            smoke_density <- max([smoke_density - smoke_decay, 0.0]);
            if (smoke_density <= 0.05 and !burning) {
                smoky <- false;
                color <- #transparent;
            }

            list<grid_cell> nb_open <- self.neighbors where (!each.is_obstacle);
            loop nb over: nb_open {
                point dir_vec <- {nb.location.x - src_loc.x, nb.location.y - src_loc.y};
                float dir_mag <- norm(dir_vec);
                if (dir_mag > 0.0) {
                    point norm_dir <- dir_vec / dir_mag;
                    float alignment <- (norm_wind = {0.0,0.0}) ? 0.0
                        : (norm_dir.x * norm_wind.x + norm_dir.y * norm_wind.y);
                    float dyn_prob <- smoke_spread_probability * max([0.15, 1.0 + alignment * 2.5]);

                    if (rnd(1.0) < dyn_prob) {
                        nb.smoky <- true;
                        float ratio <- 0.65 + (max([alignment, 0.0]) * 0.20);
                        float transferred <- src_density * ratio;
                        nb.smoke_density <- min([max([nb.smoke_density, transferred]), 1.0]);

                        if (!nb.burning) {
                            int g <- int(230 - (nb.smoke_density * 170));
                            nb.color <- rgb(g, g, g, 180);
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 6. REFLEX LAN LỬA TRÊN MẶT BẰNG 2D HIỂN THỊ (FOREGROUND SPREAD)
    // =========================================================================
    reflex spread_fire when: fire_started {
        sim_ticks <- sim_ticks + 1;

        ask floor_interior_cells where (each.burning) {
            fire_power <- min([fire_power + fire_growth_rate, 1.0]);

            int r_val <- 255;
            int g_val <- int(160 * (1.0 - fire_power));
            color <- rgb(r_val, g_val, 0, 220);

            ask neighbors where (!each.is_obstacle and !each.burning) {
                if (rnd(1.0) < fire_spread_probability) {
                    self.burning       <- true;
                    self.fire_power    <- 0.7;
                    self.smoky         <- true;
                    self.smoke_density <- 1.0;
                    self.color         <- rgb(255, 80, 0, 220);
                }
            }
        }
    }
}
