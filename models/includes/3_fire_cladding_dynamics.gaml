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
    // THAM SỐ THỜI GIAN & LAN TRUYỀN MẶT BẰNG 2D (HIỆU CHUẨN STEP = 0.5S)
    // =========================================================================
    float step <- 0.5 #s;

    // Hướng gió tự nhiên trong phòng: lan tỏa đẳng hướng tròn đều (không bị lệch lên trên)
    point wind_direction <- {0.0, 0.0};

    // Xác suất lan truyền vi mô trên mặt bằng (tương đương chu kỳ 0.5s)
    // Tinh chỉnh theo Phương án 1: Giảm xác suất để lửa và khói lan từ từ trong 45-60s
    float fire_spread_probability  <- 0.06;   // Xác suất lửa bén ô lân cận (giảm từ 0.16 -> 0.06)
    float smoke_spread_probability <- 0.10;   // Xác suất khói lan ô lân cận (giảm từ 0.25 -> 0.10)
    float smoke_decay              <- 0.015;  // Suy giảm nồng độ khói
    float fire_growth_rate         <- 0.04;   // Tăng cường độ lửa

    // Điều khiển trạng thái toàn cục
    bool  fire_started       <- false; // Đã click đặt lửa trong phòng
    bool  cladding_ignited   <- false; // Lửa đã chạm cửa sổ -> Cladding mặt đứng bắt đầu cháy
    int   sim_ticks          <- 0;
    int   fire_phase         <- 0;     // 0: Chưa cháy, 1: Cháy trong phòng, 2: Cladding leo đứng, 3: Crown & Chữ V

    // Tọa độ điểm xuất phát cháy ban đầu (để dóng thẳng trục đứng cho các tầng trên)
    point fire_origin_loc    <- {91.5, 22.5}; // Mặc định vị trí bếp Flat 16 phía Đông

    // Điều khiển lan truyền mặt đứng có độ trễ hợp lý
    // Tinh chỉnh theo Phương án 1: 18 ticks x 0.5s = 9.0s mỗi tầng (leo hết tháp ~3 phút)
    int   highest_east_floor <- 4;
    int   fire_origin_floor  <- 4;     // Tầng phát hỏa ban đầu
    int   v_lowest_floor     <- 24;    // Đỉnh khởi đầu chữ V ngược (tầng 24)
    bool  crown_reached      <- false;
    int   vertical_interval  <- 18;    // 18 ticks (9.0 giây) mỗi tầng, tạo độ trễ nhịp nhàng tự nhiên

    // --- CẢI TIẾN 2: FRONTIER WAVEFRONT TRACKING CHO TẦNG ĐANG HIỂN THỊ (FOREGROUND) ---
    list<grid_cell> active_burning_cells  <- [];
    list<grid_cell> active_fire_frontier  <- [];
    list<grid_cell> active_smoky_cells    <- [];
    list<grid_cell> active_smoke_frontier <- [];

    // =========================================================================
    // A. BỘ ĐỆM ĐA TẦNG: LƯU & NẠP SNAPSHOT TẾ BÀO LƯỚI KHI ĐỔI TẦNG (CẢI TIẾN 4)
    // =========================================================================

    // Lưu snapshot tầng đang hiển thị vào floor_level_agt (Vectorized O(K) cực nhanh)
    action save_current_floor_state {
        floor_level_agt cur_fl <- floor_map contains_key selected_floor ? floor_map[selected_floor] : nil;
        if (cur_fl = nil) { return; }

        cur_fl.floor_burning_cells     <- active_burning_cells collect each.cell_id;
        cur_fl.floor_fire_power        <- map(active_burning_cells collect (each.cell_id::each.fire_power));
        cur_fl.floor_fire_frontier     <- active_fire_frontier collect each.cell_id;
        cur_fl.floor_smoky_cells       <- active_smoky_cells collect each.cell_id;
        cur_fl.floor_smoke_density_map <- map(active_smoky_cells collect (each.cell_id::each.smoke_density));
        cur_fl.floor_smoke_frontier    <- active_smoke_frontier collect each.cell_id;
    }

    // Nạp snapshot từ floor_level_agt lên lưới grid_cell và tái tạo active lists
    action restore_active_floor_state {
        floor_level_agt cur_fl <- floor_map contains_key selected_floor ? floor_map[selected_floor] : nil;
        if (cur_fl = nil) { return; }

        // Xóa trắng nhanh chỉ các ô active hiện tại (O(K) thay vì O(15,000))
        ask (active_burning_cells + active_smoky_cells) {
            self.burning       <- false;
            self.fire_power    <- 0.0;
            self.smoky         <- false;
            self.smoke_density <- 0.0;
            self.color         <- #transparent;
        }
        active_burning_cells  <- [];
        active_fire_frontier  <- [];
        active_smoky_cells    <- [];
        active_smoke_frontier <- [];

        // Nếu tầng này chưa bắt lửa và chưa có khói -> giữ nguyên mặt bằng sạch
        if (cur_fl.fire_start_tick = -1 and empty(cur_fl.floor_burning_cells) and empty(cur_fl.floor_smoky_cells)) {
            return;
        }

        // Phục hồi các ô khói
        list<grid_cell> restored_smoky <- [];
        loop sid over: cur_fl.floor_smoky_cells {
            grid_cell cell <- grid_cell(sid);
            if (cell != nil and !cell.is_obstacle) {
                cell.smoky         <- true;
                cell.smoke_density <- cur_fl.floor_smoke_density_map contains_key sid ? cur_fl.floor_smoke_density_map[sid] : 0.5;
                int g_val <- int(230 - (cell.smoke_density * 170));
                cell.color <- rgb(g_val, g_val, g_val, 185);
                restored_smoky <- restored_smoky + [cell];
            }
        }
        active_smoky_cells <- restored_smoky;

        // Phục hồi biên khói
        list<grid_cell> restored_s_front <- [];
        loop sfid over: cur_fl.floor_smoke_frontier {
            grid_cell cell <- grid_cell(sfid);
            if (cell != nil and !cell.is_obstacle) {
                restored_s_front <- restored_s_front + [cell];
            }
        }
        active_smoke_frontier <- restored_s_front;

        // Phục hồi các ô lửa
        list<grid_cell> restored_burning <- [];
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
                restored_burning <- restored_burning + [cell];
            }
        }
        active_burning_cells <- restored_burning;

        // Phục hồi biên lửa
        list<grid_cell> restored_f_front <- [];
        loop bfid over: cur_fl.floor_fire_frontier {
            grid_cell cell <- grid_cell(bfid);
            if (cell != nil and !cell.is_obstacle) {
                restored_f_front <- restored_f_front + [cell];
            }
        }
        active_fire_frontier <- restored_f_front;
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
        list<grid_cell> fire_entry_cells <- floor_open_cells where (each.location distance_to entry_point <= 2.2);

        if (empty(fire_entry_cells)) {
            fire_entry_cells <- [floor_open_cells closest_to entry_point];
        }

        // Khói lan sâu vào phòng ngay từ khi cửa sổ vỡ vụn (bán kính ~6.5m, đi trước ngọn lửa)
        list<grid_cell> smoke_entry_cells <- floor_open_cells where (each.location distance_to entry_point <= 6.5);
        if (empty(smoke_entry_cells)) {
            smoke_entry_cells <- fire_entry_cells;
        }

        list<int> b_idx <- [];
        map<int, float> f_pow <- map([]);
        loop c over: fire_entry_cells {
            b_idx <- b_idx + [c.cell_id];
            f_pow[c.cell_id] <- 0.85;
        }

        list<int> s_idx <- [];
        map<int, float> s_dens <- map([]);
        loop c over: smoke_entry_cells {
            s_idx <- s_idx + [c.cell_id];
            float dist <- c.location distance_to entry_point;
            s_dens[c.cell_id] <- max([0.35, 1.0 - (dist / 6.5) * 0.6]);
        }

        fl.floor_burning_cells     <- b_idx;
        fl.floor_fire_power        <- f_pow;
        fl.floor_fire_frontier     <- b_idx;
        fl.floor_smoky_cells       <- s_idx;
        fl.floor_smoke_density_map <- s_dens;

        list<grid_cell> s_front_cells <- smoke_entry_cells where (each.location distance_to entry_point >= 4.0);
        if (empty(s_front_cells)) {
            fl.floor_smoke_frontier <- s_idx;
        } else {
            list<int> sf_idx <- [];
            loop fc over: s_front_cells {
                sf_idx <- sf_idx + [fc.cell_id];
            }
            fl.floor_smoke_frontier <- sf_idx;
        }

        // Nếu tầng này đang là tầng hiển thị trên màn hình, nạp ngay lập tức lên grid_cell
        if (f_id = selected_floor) {
            do restore_active_floor_state;
        }
    }

    // =========================================================================
    // 1. CLICK CHUỘT: ĐẶT ĐIỂM CHÁY TẠI VỊ TRÍ BẤT KỲ TRÊN MẶT BẰNG
    // =========================================================================
    action place_fire_at_click(point click_pt <- nil) {
        if (fire_started) {
            write "[Fire] Đám cháy đã được kích hoạt rồi. Đang tiếp tục mô phỏng!";
            return;
        }
        point click_loc <- (click_pt != nil) ? click_pt : #user_location;

        if (click_loc.x < 49.0 or click_loc.x > 93.0 or click_loc.y < 16.0 or click_loc.y > 60.0) {
            write "[Fire] Vui lòng Click bên trong phạm vi mặt bằng tòa nhà (bên phải)!";
            return;
        }

        grid_cell target_cell <- grid_cell(click_loc);
        if (target_cell = nil) { target_cell <- grid_cell closest_to click_loc; }
        if (target_cell = nil or target_cell.is_obstacle) {
            write "[Fire] Không thể đặt lửa lên tường / cột / vật cản!";
            return;
        }

        fire_origin_loc   <- click_loc;
        fire_origin_floor <- selected_floor;
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

        active_burning_cells  <- [target_cell];
        active_fire_frontier  <- [target_cell];
        active_smoky_cells    <- [target_cell];
        active_smoke_frontier <- [target_cell];

        floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
        if (cur_fl != nil) {
            cur_fl.interior_fire          <- true;
            cur_fl.fire_start_tick        <- 0;
            cur_fl.floor_initialized_fire <- true;
            cur_fl.floor_smoke_density    <- 0.4;
            // Lưu lại điểm cháy vào buffer tầng đang chọn
            cur_fl.floor_burning_cells     <- [target_cell.cell_id];
            cur_fl.floor_fire_power        <- [target_cell.cell_id::1.0];
            cur_fl.floor_fire_frontier     <- [target_cell.cell_id];
            cur_fl.floor_smoky_cells       <- [target_cell.cell_id];
            cur_fl.floor_smoke_density_map <- [target_cell.cell_id::1.0];
            cur_fl.floor_smoke_frontier    <- [target_cell.cell_id];
        }

        write "==================================================================";
        write ">>> [BƯỚC 1: KHỞI PHÁT] Đã đặt điểm cháy tại: " + click_loc + " (Tầng " + selected_floor + ")!";
        write ">>> Ngọn lửa và khói đang bắt đầu lan từ từ trong phòng...";
        write ">>> (Mặt đứng bên trái chưa cháy cho đến khi ngọn lửa lan chạm tới mép cửa sổ ngoài)";
        write "==================================================================";
    }

    // =========================================================================
    // 2. REFLEX KIỂM TRA LỬA LAN TỚI CỬA SỔ NGOÀI (TỐI ƯU O(K) TRÊN ACTIVE BURNING)
    // =========================================================================
    reflex check_window_breakout when: (fire_started and !cladding_ignited) {
        list<grid_cell> burning_windows <- active_burning_cells where (each.is_window);

        if (!empty(burning_windows)) {
            cladding_ignited   <- true;
            fire_phase         <- 2;
            highest_east_floor <- fire_origin_floor;

            grid_cell first_win <- first(burning_windows);
            if (first_win != nil) {
                fire_origin_loc <- first_win.location;
            }

            floor_level_agt cur_fl <- floor_map contains_key fire_origin_floor ? floor_map[fire_origin_floor] : nil;
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
    //    Có độ trễ 3.5 giây mỗi tầng (vertical_interval = 7 chu kỳ x 0.5s)
    // =========================================================================
    reflex cladding_vertical_controller when: cladding_ignited {
        // GIAI ĐOẠN 1: LAN THẲNG ĐỨNG TRÊN MẶT ĐÔNG LÊN ĐẾN ĐỈNH (test_max_floor)
        if (!crown_reached) {
            if (sim_ticks mod vertical_interval = 0) {
                if (highest_east_floor < test_max_floor) {
                    highest_east_floor <- highest_east_floor + 1;
                    floor_level_agt next_fl <- floor_map contains_key highest_east_floor ? floor_map[highest_east_floor] : nil;
                    if (next_fl != nil) {
                        next_fl.clad_east           <- 0.6;
                        next_fl.floor_smoke_density <- 0.7;
                        // Kích hoạt bứt phá cháy nội thất ngầm cho tầng này
                        do ignite_floor_interior_entry(highest_east_floor);
                    }
                    write ">>> [CLADDING MẶT ĐÔNG] Lửa lan thẳng đứng lên TẦNG " + highest_east_floor;

                    if (highest_east_floor = test_max_floor) {
                        crown_reached <- true;
                        v_lowest_floor <- test_max_floor;
                        fire_phase    <- 3;
                        write "==================================================================";
                        write ">>> [CROWN/TOP] LỬA ĐÃ LAN ĐẾN ĐỈNH TẦNG " + test_max_floor + "!";
                        write "==================================================================";
                    }
                }
            }
        }

        // GIAI ĐOẠN 2: LAN ĐỈNH VÀ PHÁT TRIỂN CHỮ V NGƯỢC XUỐNG BẮC/NAM/TÂY
        else if (crown_reached) {
            floor_level_agt f_top <- first(floor_level_agt where (each.floor_id = test_max_floor));
            if (f_top != nil) {
                if (f_top.clad_north <= 0.1) { f_top.clad_north <- 0.6; }
                if (f_top.clad_south <= 0.1) { f_top.clad_south <- 0.6; }
                if (f_top.clad_west  <= 0.1) { f_top.clad_west  <- 0.6; }
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
    // 4. REFLEX TIẾN TRÌNH LAN TRUYỀN NỀN (TỐI ƯU MULTI-RATE THEO STEP 0.5S)
    //    Chạy mỗi 2 ticks (1 giây mô phỏng), giảm tải 50% CPU cho mô phỏng đa tầng ngầm
    // =========================================================================
    reflex background_floors_simulation when: (fire_started and (sim_ticks mod 2 = 0)) {
        float dt_scale <- 2.0;
        float scaled_fire_prob  <- 1.0 - ((1.0 - fire_spread_probability) ^ 2);
        float scaled_smoke_prob <- 1.0 - ((1.0 - (smoke_spread_probability * 1.5)) ^ 2);

        list<floor_level_agt> bg_floors <- floor_level_agt where (each.floor_id != selected_floor and (!empty(each.floor_burning_cells) or !empty(each.floor_smoky_cells)));

        loop fl over: bg_floors {
            // --- A. TIẾN TRÌNH LỬA NỀN ---
            loop bid over: fl.floor_burning_cells {
                float cur_fp <- fl.floor_fire_power contains_key bid ? fl.floor_fire_power[bid] : 0.7;
                fl.floor_fire_power[bid] <- min([cur_fp + (fire_growth_rate * dt_scale), 1.0]);
            }

            list<int> cur_f_front <- fl.floor_fire_frontier;
            if (empty(cur_f_front) and !empty(fl.floor_burning_cells)) {
                cur_f_front <- fl.floor_burning_cells;
            }

            list<int> next_f_front <- [];
            list<int> batch_new_burning <- [];
            list<int> batch_new_smoke   <- [];

            loop bid over: cur_f_front {
                grid_cell fc <- grid_cell(bid);
                if (fc != nil) {
                    list<grid_cell> nb_open <- fc.neighbors where (!each.is_obstacle and !(fl.floor_fire_power contains_key each.cell_id));
                    if (!empty(nb_open)) {
                        bool any_uninfected <- false;
                        loop nb over: nb_open {
                            if (!(fl.floor_fire_power contains_key nb.cell_id) and rnd(1.0) < scaled_fire_prob) {
                                fl.floor_fire_power[nb.cell_id] <- 0.7;
                                batch_new_burning <- batch_new_burning + [nb.cell_id];
                                next_f_front <- next_f_front + [nb.cell_id];

                                if (!(fl.floor_smoke_density_map contains_key nb.cell_id)) {
                                    fl.floor_smoke_density_map[nb.cell_id] <- 1.0;
                                    batch_new_smoke <- batch_new_smoke + [nb.cell_id];
                                }
                            } else if (!(fl.floor_fire_power contains_key nb.cell_id)) {
                                any_uninfected <- true;
                            }
                        }
                        if (any_uninfected) {
                            next_f_front <- next_f_front + [bid];
                        }
                    }
                }
            }
            if (!empty(batch_new_burning)) {
                fl.floor_burning_cells <- fl.floor_burning_cells + batch_new_burning;
            }
            if (!empty(batch_new_smoke)) {
                fl.floor_smoky_cells    <- fl.floor_smoky_cells + batch_new_smoke;
                fl.floor_smoke_frontier <- remove_duplicates(fl.floor_smoke_frontier + batch_new_smoke);
            }
            fl.floor_fire_frontier <- remove_duplicates(next_f_front);

            // --- B. TIẾN TRÌNH KHÓI NỀN ---
            list<int> active_smoky <- [];
            loop sid over: fl.floor_smoky_cells {
                float cur_d <- fl.floor_smoke_density_map contains_key sid ? fl.floor_smoke_density_map[sid] : 0.5;
                cur_d <- max([cur_d - (smoke_decay * dt_scale), 0.0]);
                fl.floor_smoke_density_map[sid] <- cur_d;
                if (cur_d > 0.05 or (fl.floor_fire_power contains_key sid)) {
                    active_smoky <- active_smoky + [sid];
                }
            }
            fl.floor_smoky_cells <- remove_duplicates(active_smoky);

            list<int> cur_s_front <- fl.floor_smoke_frontier;
            if (empty(cur_s_front) and !empty(fl.floor_smoky_cells)) {
                cur_s_front <- fl.floor_smoky_cells;
            }

            list<int> next_s_front <- [];
            list<int> batch_new_smoky_only <- [];

            loop sid over: cur_s_front {
                grid_cell sc <- grid_cell(sid);
                if (sc != nil) {
                    float cur_density <- fl.floor_smoke_density_map contains_key sid ? fl.floor_smoke_density_map[sid] : 0.6;
                    list<grid_cell> nb_open <- sc.neighbors where (!each.is_obstacle and !(fl.floor_smoke_density_map contains_key each.cell_id));
                    if (!empty(nb_open)) {
                        bool any_uninfected <- false;
                        loop nb over: nb_open {
                            if (!(fl.floor_smoke_density_map contains_key nb.cell_id) and rnd(1.0) < scaled_smoke_prob) {
                                float transferred <- cur_density * 0.70;
                                float old_nb_d <- fl.floor_smoke_density_map contains_key nb.cell_id ? fl.floor_smoke_density_map[nb.cell_id] : 0.0;
                                float final_d <- min([max([old_nb_d, transferred]), 1.0]);

                                fl.floor_smoke_density_map[nb.cell_id] <- final_d;
                                batch_new_smoky_only <- batch_new_smoky_only + [nb.cell_id];
                                next_s_front <- next_s_front + [nb.cell_id];
                            } else if (!(fl.floor_smoke_density_map contains_key nb.cell_id)) {
                                any_uninfected <- true;
                            }
                        }
                        if (any_uninfected) {
                            next_s_front <- next_s_front + [sid];
                        }
                    }
                }
            }
            if (!empty(batch_new_smoky_only)) {
                fl.floor_smoky_cells <- fl.floor_smoky_cells + batch_new_smoky_only;
            }
            fl.floor_smoke_frontier <- remove_duplicates(next_s_front);
        }
    }

    // =========================================================================
    // 5. REFLEX LAN KHÓI TRÊN MẶT BẰNG 2D HIỂN THỊ (CẢI TIẾN 2: WAVEFRONT FRONTIER)
    // =========================================================================
    reflex spread_smoke when: fire_started {
        // A. Suy giảm nồng độ khói trên các ô active_smoky_cells
        list<grid_cell> still_smoky <- [];
        ask active_smoky_cells {
            self.smoke_density <- max([self.smoke_density - smoke_decay, 0.0]);
            if (self.smoke_density <= 0.05 and !self.burning) {
                self.smoky <- false;
                self.color <- #transparent;
            } else {
                still_smoky <- still_smoky + [self];
                if (!self.burning) {
                    int g <- int(230 - (self.smoke_density * 170));
                    self.color <- rgb(g, g, g, 180);
                }
            }
        }
        active_smoky_cells <- remove_duplicates(still_smoky);

        // B. Lan khói chỉ từ danh sách biên active_smoke_frontier
        list<grid_cell> cur_s_front <- active_smoke_frontier;
        if (empty(cur_s_front) and !empty(active_smoky_cells)) {
            cur_s_front <- active_smoky_cells;
        }

        list<grid_cell> next_s_front <- [];
        list<grid_cell> batch_new_smoky <- [];

        loop sc over: cur_s_front {
            list<grid_cell> nb_open <- sc.neighbors where (!each.is_obstacle and !each.smoky);
            if (!empty(nb_open)) {
                bool any_uninfected <- false;
                loop nb over: nb_open {
                    if (!nb.smoky and rnd(1.0) < (smoke_spread_probability * 1.8)) {
                        nb.smoky <- true;
                        float transferred <- sc.smoke_density * 0.70;
                        nb.smoke_density <- min([max([nb.smoke_density, transferred]), 1.0]);
                        if (!nb.burning) {
                            int g <- int(230 - (nb.smoke_density * 170));
                            nb.color <- rgb(g, g, g, 180);
                        }
                        batch_new_smoky <- batch_new_smoky + [nb];
                        next_s_front <- next_s_front + [nb];
                    } else if (!nb.smoky) {
                        any_uninfected <- true;
                    }
                }
                if (any_uninfected) {
                    next_s_front <- next_s_front + [sc];
                }
            }
        }

        if (!empty(batch_new_smoky)) {
            active_smoky_cells <- remove_duplicates(active_smoky_cells + batch_new_smoky);
        }
        active_smoke_frontier <- remove_duplicates(next_s_front);
    }

    // =========================================================================
    // 6. REFLEX LAN LỬA TRÊN MẶT BẰNG 2D HIỂN THỊ (CẢI TIẾN 2: WAVEFRONT FRONTIER)
    // =========================================================================
    reflex spread_fire when: fire_started {
        sim_ticks <- sim_ticks + 1;

        // A. Cường độ lửa tăng dần trên các ô active_burning_cells
        ask active_burning_cells {
            self.fire_power <- min([self.fire_power + fire_growth_rate, 1.0]);
            int r_val <- 255;
            int g_val <- int(160 * (1.0 - self.fire_power));
            self.color <- rgb(r_val, g_val, 0, 220);
        }

        // B. Lan lửa chỉ từ danh sách biên active_fire_frontier
        list<grid_cell> cur_f_front <- active_fire_frontier;
        if (empty(cur_f_front) and !empty(active_burning_cells)) {
            cur_f_front <- active_burning_cells;
        }

        list<grid_cell> next_f_front <- [];
        list<grid_cell> batch_new_burning <- [];
        list<grid_cell> batch_new_smoke   <- [];

        loop fc over: cur_f_front {
            list<grid_cell> nb_unburnt <- fc.neighbors where (!each.is_obstacle and !each.burning);
            if (!empty(nb_unburnt)) {
                bool any_unburnt <- false;
                loop nb over: nb_unburnt {
                    if (!nb.burning and rnd(1.0) < fire_spread_probability) {
                        nb.burning        <- true;
                        nb.fire_power     <- 0.7;
                        nb.color          <- rgb(255, 80, 0, 220);
                        batch_new_burning <- batch_new_burning + [nb];
                        next_f_front      <- next_f_front + [nb];

                        if (!nb.smoky) {
                            nb.smoky         <- true;
                            nb.smoke_density <- 1.0;
                            batch_new_smoke  <- batch_new_smoke + [nb];
                        }
                    } else if (!nb.burning) {
                        any_unburnt <- true;
                    }
                }
                if (any_unburnt) {
                    next_f_front <- next_f_front + [fc];
                }
            }
        }

        if (!empty(batch_new_burning)) {
            active_burning_cells <- remove_duplicates(active_burning_cells + batch_new_burning);
        }
        if (!empty(batch_new_smoke)) {
            active_smoky_cells    <- remove_duplicates(active_smoky_cells + batch_new_smoke);
            active_smoke_frontier <- remove_duplicates(active_smoke_frontier + batch_new_smoke);
        }
        active_fire_frontier <- remove_duplicates(next_f_front);
    }
}
