/**
 * Module: 3_fire_cladding_dynamics.gaml
 * Author: DOAN TAI LOC & Antigravity
 * Description: MODULE LỬA & KHÓI — DUAL-LAYER SYNCHRONIZED SIMULATION
 *
 *   1. ĐỒNG BỘ TỌA ĐỘ PHÁT TÁN (ALIGNED VERTICAL PLUME):
 *      - Đám cháy ở các tầng trên XUẤT PHÁT TẠI ĐÚNG VỊ TRÍ CỬA SỔ THẲNG HÀNG VỚI NGUỒN CHÁY TẦNG DƯỚI.
 *      - Tuyệt đối không phát tán từ toàn bộ cả mặt tường 22m.
 *      - Lửa và khói lan tỏa hình quạt tự nhiên từ đúng vị trí cửa sổ đó vào trong phòng.
 *
 *   2. ĐỘ TRỄ LAN TRUYỀN PHÙ HỢP (REALISTIC VERTICAL DELAY):
 *      - Sau khi cửa sổ vỡ, ngọn lửa mặt ngoài nung nóng Cladding và liếm lên tầng trên
 *        với độ trễ phù hợp (~3.5 - 4.0 giây mỗi tầng), đủ thời gian để quan sát từng tầng bốc cháy.
 *
 *   3. TIẾN TRÌNH KHÓI VÀ LỬA LIÊN TỤC TRONG NỀN:
 *      - Khói lan nhanh gấp 2.5 - 3 lần ngọn lửa.
 *      - Sảnh trung tâm và buồng thang bộ chỉ bị nhiễm khói khi đám khói lan đủ sâu (smoke_depth >= 16m).
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

    // Xác suất lan truyền vi mô trên mặt bằng (từ evacuation_2d_mvp.gaml)
    float fire_spread_probability  <- 0.035;  // Xác suất lửa bén ô lân cận
    float smoke_spread_probability <- 0.14;   // Xác suất khói lan ô lân cận
    float smoke_decay              <- 0.005;  // Suy giảm nồng độ khói
    float fire_growth_rate         <- 0.02;   // Tăng cường độ lửa

    // Điều khiển trạng thái
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
    // 1. CLICK CHUỘT: ĐẶT ĐIỂM CHÁY TẠI VỊ TRÍ BẤT KỲ TRÊN MẶT BẰNG
    // =========================================================================
    action place_fire_at_click {
        point click_loc <- #user_location;

        // Kiểm tra vị trí click phải nằm trong phạm vi sàn tòa nhà
        if (click_loc.x < 49.0 or click_loc.x > 93.0 or click_loc.y < 16.0 or click_loc.y > 60.0) {
            write "[Fire] Vui lòng Click bên trong phạm vi mặt bằng tòa nhà (bên phải)!";
            return;
        }

        grid_cell target_cell <- grid_cell closest_to click_loc;
        if (target_cell = nil or target_cell.is_obstacle) {
            write "[Fire] Không thể đặt lửa lên tường / cột / vật cản!";
            return;
        }

        // Lưu lại tọa độ nguồn cháy để dóng thẳng hàng trục đứng cho các tầng phía trên
        fire_origin_loc <- click_loc;

        // Khởi động đám cháy ban đầu trong phòng
        fire_started <- true;
        sim_ticks    <- 0;
        fire_phase   <- 1;

        ask target_cell {
            burning       <- true;
            fire_power    <- 1.0;
            smoky         <- true;
            smoke_density <- 1.0;
            color         <- #red;
        }

        // Đánh dấu tầng đang chọn bắt đầu có cháy nội thất và khói
        floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
        if (cur_fl != nil) {
            cur_fl.interior_fire        <- true;
            cur_fl.fire_start_tick      <- 0;
            cur_fl.interior_burn_depth  <- 1.0;
            cur_fl.interior_smoke_depth <- 2.5; // Khói lan trước lửa
            cur_fl.floor_smoke_density  <- 0.4;
        }

        write "==================================================================";
        write ">>> [BƯỚC 1: KHỞI PHÁT] Đã đặt điểm cháy tại: " + click_loc + " (Tầng " + selected_floor + ")!";
        write ">>> Ngọn lửa và khói đang bắt đầu lan từ từ trong phòng...";
        write ">>> (Mặt đứng bên trái chưa cháy cho đến khi ngọn lửa lan chạm tới mép cửa sổ ngoài)";
        write "==================================================================";
    }

    // =========================================================================
    // 2. REFLEX KIỂM TRA LỬA LAN TỚI CỬA SỔ NGOÀI (BREAKOUT CHECK)
    //    Chỉ kích hoạt cháy Cladding mặt đứng khi lửa chạm vào cửa sổ!
    // =========================================================================
    reflex check_window_breakout when: (fire_started and !cladding_ignited) {
        // Kiểm tra xem trên mặt bằng tầng hiện tại, có ô cửa sổ nào bị bắt lửa chưa
        list<grid_cell> burning_windows <- grid_cell where (each.is_window and each.burning);

        if (!empty(burning_windows)) {
            cladding_ignited   <- true;
            fire_phase         <- 2;
            highest_east_floor <- selected_floor;

            // Cập nhật trục dóng cột lửa theo vị trí ô cửa sổ thực tế bị cháy
            grid_cell first_win <- first(burning_windows);
            if (first_win != nil) {
                fire_origin_loc <- first_win.location;
            }

            floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
            if (cur_fl != nil) {
                cur_fl.window_broken       <- true;
                cur_fl.clad_east           <- 0.6; // Bắt đầu bén Cladding mặt Đông
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
        // ---------------------------------------------------------------------
        // GIAI ĐOẠN 1: LAN THẲNG ĐỨNG TRÊN MẶT ĐÔNG LÊN ĐẾN TẦNG 24 (CROWN)
        // ---------------------------------------------------------------------
        if (!crown_reached) {
            // Cứ sau mỗi vertical_interval ticks (~3.5s), lửa mới leo lên 1 tầng
            if (sim_ticks mod vertical_interval = 0) {
                if (highest_east_floor < 24) {
                    highest_east_floor <- highest_east_floor + 1;
                    floor_level_agt next_fl <- first(floor_level_agt where (each.floor_id = highest_east_floor));
                    if (next_fl != nil) {
                        next_fl.clad_east            <- 0.6; // Đang cháy đỏ rực
                        next_fl.window_broken        <- true;
                        next_fl.interior_fire        <- true;
                        next_fl.fire_start_tick      <- sim_ticks; // Bắt đầu tính giờ cháy tầng này
                        next_fl.interior_burn_depth  <- 1.0;
                        next_fl.interior_smoke_depth <- 3.0; // Khói bốc vào phòng trước lửa
                        next_fl.floor_smoke_density  <- 0.7;
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

        // ---------------------------------------------------------------------
        // GIAI ĐOẠN 2: LAN ĐỈNH CROWN VÀ PHÁT TRIỂN CHỮ V NGƯỢC XUỐNG BẮC/NAM/TÂY
        // ---------------------------------------------------------------------
        if (crown_reached) {
            floor_level_agt f24 <- first(floor_level_agt where (each.floor_id = 24));
            if (f24 != nil) {
                if (f24.clad_north <= 0.1) { f24.clad_north <- 0.6; }
                if (f24.clad_south <= 0.1) { f24.clad_south <- 0.6; }
            }

            // Chữ V lan ngược từ trên xuống dưới với độ trễ tương tự
            if (sim_ticks mod vertical_interval = 0) {
                if (v_lowest_floor > 4) {
                    v_lowest_floor <- v_lowest_floor - 1;
                    floor_level_agt down_fl <- first(floor_level_agt where (each.floor_id = v_lowest_floor));
                    if (down_fl != nil) {
                        down_fl.clad_north           <- 0.6;
                        down_fl.clad_south           <- 0.6;
                        down_fl.clad_west            <- 0.5; // Khép kín sang mặt Tây
                        down_fl.window_broken       <- true;
                        down_fl.interior_fire       <- true;
                        if (down_fl.fire_start_tick = -1) {
                            down_fl.fire_start_tick      <- sim_ticks;
                            down_fl.interior_burn_depth  <- 1.0;
                            down_fl.interior_smoke_depth <- 3.0;
                        }
                        down_fl.floor_smoke_density <- 0.8;
                    }
                    write ">>> [CHỮ V NGƯỢC] Lửa lan xuống TẦNG " + v_lowest_floor + " (mặt Bắc, Nam & Tây)!";
                }
            }
        }

        // ---------------------------------------------------------------------
        // GIAI ĐOẠN 3: TĂNG CƯỜNG ĐỘ & CHUYỂN DẦN SANG CHÁY KIỆT (THAN HÓA > 1.5)
        // ---------------------------------------------------------------------
        ask floor_level_agt {
            if (clad_east  > 0.1) { clad_east  <- min([2.0, clad_east  + 0.0015]); }
            if (clad_north > 0.1) { clad_north <- min([2.0, clad_north + 0.0015]); }
            if (clad_south > 0.1) { clad_south <- min([2.0, clad_south + 0.0015]); }
            if (clad_west  > 0.1) { clad_west  <- min([2.0, clad_west  + 0.0015]); }
        }
    }

    // =========================================================================
    // 4. TIẾN TRÌNH CHÁY & KHÓI LIÊN TỤC TRONG NỀN CỦA TẤT CẢ 25 TẦNG
    //    Khói lan nhanh gấp 2.5 - 3 lần ngọn lửa (smoke_depth vs burn_depth)!
    // =========================================================================
    reflex multi_floor_background_progress when: fire_started {
        sim_ticks <- sim_ticks + 1;

        // Cập nhật cả ngọn lửa lẫn đám khói độc cho tất cả các tầng đã bắt lửa
        ask floor_level_agt where (each.fire_start_tick >= 0) {
            interior_burn_depth  <- min([14.0, interior_burn_depth + 0.015]);
            interior_smoke_depth <- min([35.0, interior_smoke_depth + 0.045]); // Khói lan nhanh gấp 3 lần lửa
            floor_smoke_density  <- min([1.0, floor_smoke_density + 0.002]);
        }
    }

    // =========================================================================
    // 5. REFLEX LAN KHÓI TRÊN MẶT BẰNG 2D (CHỈ TRONG TÒA NHÀ)
    // =========================================================================
    reflex spread_smoke when: fire_started {
        float wind_mag <- norm(wind_direction);
        point norm_wind <- (wind_mag = 0.0) ? {0.0, 0.0} : (wind_direction / wind_mag);

        // Chỉ xét các ô khói trong phạm vi tòa nhà
        ask grid_cell where (each.smoky and each.location.x >= 49.0 and each.location.x <= 93.0 and each.location.y >= 16.0 and each.location.y <= 60.0) {
            point src_loc     <- self.location;
            float src_density <- self.smoke_density;

            smoke_density <- max([smoke_density - smoke_decay, 0.0]);
            if (smoke_density <= 0.05 and !burning) {
                smoky <- false;
                color <- #transparent;
            }

            // Chỉ lan sang các ô mở (không phải vật cản và không phải ngoài tòa nhà)
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
    // 6. REFLEX LAN LỬA TRÊN MẶT BẰNG 2D (CHỈ TRONG TÒA NHÀ)
    // =========================================================================
    reflex spread_fire when: fire_started {
        // Chỉ xét các ô lửa trong phạm vi tòa nhà
        ask grid_cell where (each.burning and each.location.x >= 49.0 and each.location.x <= 93.0 and each.location.y >= 16.0 and each.location.y <= 60.0) {
            fire_power <- min([fire_power + fire_growth_rate, 1.0]);

            int r_val <- 255;
            int g_val <- int(160 * (1.0 - fire_power));
            color <- rgb(r_val, g_val, 0, 220);

            // Lan sang các ô mở lân cận chưa cháy (hoàn toàn không lan ra ngoài không trung)
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

    // =========================================================================
    // 7. ĐỒNG BỘ MẶT BẰNG 2D KHI NGƯỜI DÙNG CLICK XEM TẦNG MỚI (SYNC ACTIVE FLOOR)
    //    Đám cháy ở các tầng trên XUẤT HIỆN TẠI ĐÚNG VỊ TRÍ CỬA SỔ DÓNG THẲNG TRỤC
    // =========================================================================
    action sync_active_floor_fire {
        floor_level_agt cur_fl <- first(floor_level_agt where (each.floor_id = selected_floor));
        if (cur_fl = nil) { return; }

        // Nếu tầng này chưa từng bị cháy -> mặt bằng hoàn toàn sạch sẽ!
        if (cur_fl.fire_start_tick = -1) {
            return;
        }

        // Tầng này đã và đang bị cháy -> khôi phục trạng thái tương ứng với thời gian cháy
        float fire_depth  <- cur_fl.interior_burn_depth;
        float smoke_depth <- cur_fl.interior_smoke_depth;
        list<grid_cell> floor_cells <- grid_cell where (each.location.x >= 49.0 and each.location.x <= 93.0 and each.location.y >= 16.0 and each.location.y <= 60.0 and !each.is_obstacle);

        // Tọa độ trục dóng cửa sổ từ tầng xuất phát ban đầu
        float origin_y <- fire_origin_loc.y;

        // ---------------------------------------------------------------------
        // A. MẶT ĐÔNG BỊ CHÁY (CỘT CLADDING THẲNG ĐỨNG THEO TRỤC ORIGIN_Y)
        //    Chỉ xuất phát từ đúng vị trí cửa sổ dóng thẳng hàng trục origin_y!
        // ---------------------------------------------------------------------
        if (cur_fl.clad_east > 0.1) {
            point east_plume_center <- {93.0, origin_y};

            // 1. Tái tạo khói: lan tỏa hình bán nguyệt từ đúng ô cửa sổ đó
            ask floor_cells {
                float dist <- self.location distance_to east_plume_center;
                if (dist <= smoke_depth) {
                    float dens <- max([0.35, cur_fl.floor_smoke_density * (1.0 - (dist / (smoke_depth + 1.0)) * 0.4)]);
                    smoky         <- true;
                    smoke_density <- max([smoke_density, dens]);
                    int g_val     <- int(230 - (dens * 170));
                    if (!burning) {
                        color <- rgb(g_val, g_val, g_val, 190);
                    }
                }
            }

            // 2. Tái tạo lửa: chỉ ở phạm vi hẹp hơn quanh đúng ô cửa sổ đó
            ask floor_cells {
                float dist <- self.location distance_to east_plume_center;
                if (dist <= fire_depth) {
                    if (rnd(1.0) < 0.85) {
                        burning       <- true;
                        fire_power    <- 0.8;
                        smoky         <- true;
                        smoke_density <- 1.0;
                        color         <- rgb(255, 60, 0);
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // B. CÁC MẶT BẮC, NAM, TÂY (KHI LỬA LAN CHỮ V HOẶC VÒNG QUA CÁC GÓC)
        // ---------------------------------------------------------------------
        // Mặt Bắc: lan từ góc Đông Bắc {91.0, 16.0}
        if (cur_fl.clad_north > 0.1) {
            point north_corner <- {91.0, 16.0};
            ask floor_cells {
                float dist <- self.location distance_to north_corner;
                if (dist <= smoke_depth) {
                    float dens <- max([0.35, cur_fl.floor_smoke_density * (1.0 - (dist / (smoke_depth + 1.0)) * 0.4)]);
                    smoky         <- true;
                    smoke_density <- max([smoke_density, dens]);
                    int g_val     <- int(230 - (dens * 170));
                    if (!burning) { color <- rgb(g_val, g_val, g_val, 190); }
                }
                if (dist <= fire_depth and rnd(1.0) < 0.85) {
                    burning       <- true;
                    fire_power    <- 0.8;
                    smoky         <- true;
                    smoke_density <- 1.0;
                    color         <- rgb(255, 60, 0);
                }
            }
        }

        // Mặt Nam: lan từ góc Đông Nam {91.0, 60.0}
        if (cur_fl.clad_south > 0.1) {
            point south_corner <- {91.0, 60.0};
            ask floor_cells {
                float dist <- self.location distance_to south_corner;
                if (dist <= smoke_depth) {
                    float dens <- max([0.35, cur_fl.floor_smoke_density * (1.0 - (dist / (smoke_depth + 1.0)) * 0.4)]);
                    smoky         <- true;
                    smoke_density <- max([smoke_density, dens]);
                    int g_val     <- int(230 - (dens * 170));
                    if (!burning) { color <- rgb(g_val, g_val, g_val, 190); }
                }
                if (dist <= fire_depth and rnd(1.0) < 0.85) {
                    burning       <- true;
                    fire_power    <- 0.8;
                    smoky         <- true;
                    smoke_density <- 1.0;
                    color         <- rgb(255, 60, 0);
                }
            }
        }

        // Mặt Tây: lan từ mép góc Tây {49.0, 38.0}
        if (cur_fl.clad_west > 0.1) {
            point west_corner <- {49.0, 38.0};
            ask floor_cells {
                float dist <- self.location distance_to west_corner;
                if (dist <= smoke_depth) {
                    float dens <- max([0.35, cur_fl.floor_smoke_density * (1.0 - (dist / (smoke_depth + 1.0)) * 0.4)]);
                    smoky         <- true;
                    smoke_density <- max([smoke_density, dens]);
                    int g_val     <- int(230 - (dens * 170));
                    if (!burning) { color <- rgb(g_val, g_val, g_val, 190); }
                }
                if (dist <= fire_depth and rnd(1.0) < 0.85) {
                    burning       <- true;
                    fire_power    <- 0.8;
                    smoky         <- true;
                    smoke_density <- 1.0;
                    color         <- rgb(255, 60, 0);
                }
            }
        }
    }
}
