-- arc for mlre
-- @sonocircuit

local arc = {}

function arc.rec_delta(n, d)
  if arc_pageNum == 1 then
    -- enc 1:
    if n == 1 then
      -- start playback
      if params:get("arc_enc_1_start") == 2 then
        if track[track_focus].play == 0 and (d > 2 or d < -2) then
          local e = {} e.t = eSTART e.i = track_focus
          event(e)
          if params:get(track_focus.."play_mode") == 3 then
            local e = {} e.t = eGATEON e.i = track_focus
            event(e)
          end
        end
      end
      -- stop playback when enc stops
      if params:get(track_focus.."play_mode") == 3 then
        inc = (inc % 100) + 1
        clock.run(
          function()
            local prev_inc = inc
            clock.sleep(0.05)
            if prev_inc == inc then
              if params:get(track_focus.."adsr_active") == 2 then
                local e = {} e.t = eGATEOFF e.i = track_focus event(e)
              else
                local e = {} e.t = eSTOP e.i = track_focus event(e)
              end
            end
          end
        )
      end
      -- set direction
      if params:get("arc_enc_1_dir") == 2 then
        if d < -2 and track[track_focus].rev == 0 then
          local e = {} e.t = eREV e.i = track_focus e.rev = 1
          event(e)
        elseif d > 2 and track[track_focus].rev == 1 then
          local e = {} e.t = eREV e.i = track_focus e.rev = 0
          event(e)
        end
      end
      -- temp warble
      if (d > 10 or d < -10) and params:get("arc_enc_1_mod") == 2 then
        if track[track_focus].play == 1 then
          clock.run(
            function()
              local speedmod = 1 - d / 80
              local n = math.pow(2, track[track_focus].speed + track[track_focus].transpose + track[track_focus].detune)
              if track[track_focus].rev == 1 then n = -n end
              if track[track_focus].tempo_map == 2 then
                local bpmmod = clock.get_tempo() / clip[i].bpm
                n = n * bpmmod
              end
              local rate = n * speedmod
              softcut.rate_slew_time(track_focus, 0.25)
              softcut.rate(track_focus, rate)
              clock.sleep(0.4)
              update_rate(track_focus)
              softcut.rate_slew_time(track_focus, track[track_focus].rate_slew)
            end
          )
        end
      end
      -- scrub
      if (d > 2 or d < -2) and params:get("arc_enc_1_mod") == 3 then
        if track[track_focus].play == 1 then
          arc_inc1 = (arc_inc1 % 12) + 1
          if arc_inc1 == 1 then
            local shift = d / scrub_sens
            local curr_pos = track[track_focus].pos_abs
            local new_pos = curr_pos + shift
            softcut.position(track_focus, new_pos)
          end
        end
      end
    -- enc 2: activate loop or move loop window
    elseif n == 2 then
      if track[track_focus].loop == 0 and (d > 2 or d < -2) and alt == 0 then
        enc2_wait = true
        local e = {}
        e.t = eLOOP
        e.i = track_focus
        e.loop = 1
        e.loop_start = track[track_focus].loop_start
        e.loop_end = track[track_focus].loop_end
        event(e)
        if params:get(track_focus.."adsr_active") == 2 then
          local e = {} e.t = eGATEON e.i = track_focus event(e)
        end
        clock.run(
          function()
            clock.sleep(0.4)
            enc2_wait = false
            arc_inc2 = 0
          end
        )
      end
      if track[track_focus].loop == 1 and alt == 1 then
        local e = {} e.t = eUNLOOP e.i = track_focus event(e)
        if params:get(track_focus.."adsr_active") == 2 then
          local e = {} e.t = eGATEOFF e.i = track_focus event(e)
        end
      end
      if track[track_focus].loop == 1 and not enc2_wait then
        arc_inc2 = (arc_inc2 % 20) + 1
        local new_loop_start = track[track_focus].loop_start + d / 200
        local new_loop_end = track[track_focus].loop_end + d / 200
        if math.abs(new_loop_start) - 1 <= track[track_focus].loop_end and math.abs(new_loop_end) <= 16 then
          track[track_focus].loop_start = util.clamp(new_loop_start, 1, 16.9)
        end
        if math.abs(new_loop_end) + 1 >= track[track_focus].loop_start and math.abs(new_loop_start) >= 1 then
          track[track_focus].loop_end = util.clamp(new_loop_end, 0.1, 16)
        end
        if arc_inc2 == 20 and track[track_focus].play == 1 and pattern_rec then
          local e = {}
          e.t = eLOOP
          e.i = track_focus
          e.loop = 1
          e.loop_start = track[track_focus].loop_start
          e.loop_end = track[track_focus].loop_end
          event(e)
        else
          local lstart = clip[track_focus].s + (track[track_focus].loop_start - 1) / 16 * clip[track_focus].l
          local lend = clip[track_focus].s + (track[track_focus].loop_end) / 16 * clip[track_focus].l
          softcut.loop_start(track_focus, lstart)
          softcut.loop_end(track_focus, lend)
        end
        if view < vLFO then dirtygrid = true end
      end
    -- enc 3: set loop start
    elseif n == 3 then
      arc_inc3 = (arc_inc3 % 20) + 1
      local new_loop_start = track[track_focus].loop_start + d / 500
      if math.abs(new_loop_start) - 1 <= track[track_focus].loop_end then
        track[track_focus].loop_start = util.clamp(new_loop_start, 1, 16.9)
      end
      if track[track_focus].loop == 1 then
        if arc_inc3 == 20 and track[track_focus].play == 1 and pattern_rec then
          local e = {}
          e.t = eLOOP
          e.i = track_focus
          e.loop = 1
          e.loop_start = track[track_focus].loop_start
          e.loop_end = track[track_focus].loop_end
          event(e)
        else
          local lstart = clip[track_focus].s + (track[track_focus].loop_start - 1) / 16 * clip[track_focus].l
          softcut.loop_start(track_focus, lstart)
        end
      end
      if view < vLFO then dirtygrid = true end
    -- enc 4: set loop end
    elseif n == 4 then
      if cutview_hold then
        arc_track_focus = util.clamp(arc_track_focus + d / 100, 1, 6)
        track_focus = math.floor(arc_track_focus)
      else
        arc_inc4 = (arc_inc4 % 20) + 1
        local new_loop_end = track[track_focus].loop_end + d / 500
        if math.abs(new_loop_end) + 1 >= track[track_focus].loop_start then
          track[track_focus].loop_end = util.clamp(new_loop_end, 0.1, 16)
        end
        if track[track_focus].loop == 1 then
          if arc_inc4 == 20 and track[track_focus].play == 1 and pattern_rec then
            local e = {}
            e.t = eLOOP
            e.i = track_focus
            e.loop = 1
            e.loop_start = track[track_focus].loop_start
            e.loop_end = track[track_focus].loop_end
            event(e)
          else
            local lend = clip[track_focus].s + (track[track_focus].loop_end) / 16 * clip[track_focus].l
            softcut.loop_end(track_focus, lend)
          end
        end
      end
      if view < vLFO then dirtygrid = true end
    end
  elseif arc_pageNum == 2 then
    if n == 1 then
      params:delta(track_focus.."vol", d / 12)
    elseif n == 2 then
      params:delta(track_focus.."pan", d / 12)
    elseif n == 3 then
      params:delta(track_focus.."cutoff", d / 16)
    elseif n == 4 then
      if cutview_hold then
        arc_track_focus = util.clamp(arc_track_focus + d / 100, 1, 6)
        track_focus = math.floor(arc_track_focus)
      else
        params:delta(track_focus.."filter_q", d / 12)
      end
    end
  elseif arc_pageNum == 3 then
    arcdelta_lfo(n, d)
  end
end

function arc.rec_draw()
  a:all(0)
  if arc_pageNum == 1 then
    -- draw positon
    a:led(1, 33 - arc_off, 8)
    --a:led(1, -track[track_focus].pos_arc + 66 - arc_off, 15)
    a:led(1, track[track_focus].pos_arc + 32 - arc_off, 15)
    -- draw loop
    a:led(2, 33 - arc_off, 8)
    local startpoint = math.ceil(track[track_focus].loop_start * 4) - 3
    local endpoint = math.ceil(track[track_focus].loop_end * 4)
    for i = startpoint, endpoint do
      a:led(2, i + 32 - arc_off, 8)
    end
    if track[track_focus].play == 1 and track[track_focus].loop == 1 then
      a:led(2, track[track_focus].pos_arc + 32 - arc_off, 15)
    end
    -- draw loop start
    a:led(3, 33 - arc_off, 8)
    for i = 0, 3 do
      a:led(3, startpoint + 32 + i - arc_off, 10 - i * 3)
    end
    if track[track_focus].play == 1 and track[track_focus].loop == 1 then
      a:led(3, track[track_focus].pos_arc + 32 - arc_off, 15)
    end
    -- draw loop end
    if cutview_hold then
      -- draw track_focus
      for i = 1, 6 do
        local off = -13
        for j = 0, 5 do
          a:led(4, (i + off) + j * 7 - 7 - arc_off, 4)
        end
        a:led(4, (i + (track_focus - 1) * 7 - 6) + 50 - arc_off, 15)
      end
    else
      a:led(4, 33 - arc_off, 8)
      for i = 0, 3 do
        a:led(4, endpoint + 32 - i - arc_off, 10 - i * 3)
      end
      if track[track_focus].play == 1 and track[track_focus].loop == 1 then
        a:led(4, track[track_focus].pos_arc + 32 - arc_off, 15)
      end
    end
  elseif arc_pageNum == 2 then
    -- draw volume
    local arc_vol = math.floor(params:get(track_focus.."vol") * 64)
    for i = 1, 64 do
      if i < arc_vol then
        a:led(1, i - arc_off, 3)
      end
      a:led(1, arc_vol - arc_off, 15)
    end
    -- draw pan
    local arc_pan = math.floor(params:get(track_focus.."pan") * 24)
    a:led (2, 1 - arc_off, 7)
    a:led (2, 25 - arc_off, 5)
    a:led (2, -23 - arc_off, 5)
    if arc_pan > 0 then
      for i = 2, arc_pan do
        a:led(2, i - arc_off, 4)
      end
    elseif arc_pan < 0 then
      for i = arc_pan + 2, 0 do
        a:led(2, i - arc_off, 4)
      end
    end
    a:led (2, arc_pan + 1 - arc_off, 15)
    -- draw cutoff
    local arc_cut = math.floor(util.explin(20, 18000, 0, 1, params:get(track_focus.."cutoff")) * 48) + 41
    a:led (3, 25 - arc_off, 5)
    a:led (3, -23 - arc_off, 5)
    for i = -22, 24 do
      if i < arc_cut - 64 then
        a:led(3, i - arc_off, 3)
      end
    end
    a:led(3, arc_cut - arc_off, 15)
    if cutview_hold then
      -- draw track_focus
      for i = 1, 6 do
        local off = -13
        for j = 0, 5 do
          a:led(4, (i + off) + j * 7 - 7 - arc_off, 4)
        end
        a:led(4, (i + (track_focus - 1) * 7 - 6) + 50 - arc_off, 15)
      end
    else
      -- draw filter_q
      arc_q = math.floor(util.explin(0.1, 4, 0, 1, params:get(track_focus.."filter_q")) * 32) + 17
      for i = 17, 49 do
        if i > arc_q then
          a:led(4, i - arc_off, 3)
        end
      end
      a:led(4, 17 - arc_off, 7)
      a:led(4, 49 - arc_off, 7)
      a:led(4, 42 - arc_off, 7)
      a:led(4, 36 - arc_off, 7)
      a:led(4, arc_q - arc_off, 15)
    end
  elseif arc_pageNum == 3 then
    arcredraw_lfo()
  end
  a:refresh()
end

function arc.lfo_delta(n, d)
  if n == 1 then
    params:delta(lfo_focus.."lfo_freq", d / 20)
  elseif n == 2 then
    params:delta(lfo_focus.."lfo_depth", d / 10)
    if params:get(lfo_focus.."lfo_depth") > 0 and params:get(lfo_focus.."lfo_state") ~= 2 then
      params:set(lfo_focus.."lfo_state", 2)
      lfo[lfo_focus].active = 1
    elseif params:get(lfo_focus.."lfo_depth") == 0 then
      params:set(lfo_focus.."lfo_state", 1)
      lfo[lfo_focus].active = 0
    end
  elseif n == 3 then
    params:delta(lfo_focus.."lfo_offset", d / 20)
  elseif n == 4 then
    arc_lfo_focus = util.clamp(arc_lfo_focus + d / 100, 1, 6)
    lfo_focus = math.floor(arc_lfo_focus)
  end
  if view == vLFO then dirtyscreen = true end
end

function arc.lfo_draw()
  a:all(0)
  -- draw lfo freq
  local lfo_frq = math.floor(util.linlin(0.1, 10, 0, 1, params:get(lfo_focus.."lfo_freq")) * 48) + 41
  a:led (1, 25 - arc_off, 5)
  a:led (1, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < lfo_frq - 64 then
      a:led(1, i - arc_off, 3)
    end
  end
  a:led(1, lfo_frq - arc_off, 15)
  -- draw lfo lfo depth
  local lfo_dth = math.floor((params:get(lfo_focus.."lfo_depth") / 100) * 48) + 41
  a:led (2, 25 - arc_off, 5)
  a:led (2, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < lfo_dth - 64 then
      a:led(2, i - arc_off, 3)
    end
  end
  a:led(2, lfo_dth - arc_off, 15)
  -- draw lfo offset
  local lfo_off = math.floor(params:get(lfo_focus.."lfo_offset") * 24)
  a:led (3, 1 - arc_off, 7)
  a:led (3, 25 - arc_off, 5)
  a:led (3, -23 - arc_off, 5)
  if lfo_off > 0 then
    for i = 2, lfo_off do
      a:led(3, i - arc_off, 4)
    end
  elseif lfo_off < 0 then
    for i = lfo_off + 2, 0 do
      a:led(3, i - arc_off, 4)
    end
  end
  a:led (3, lfo_off + 1 - arc_off, 15)
  -- draw lfo selection
  for i = 1, 6 do
    local off = -13
    for j = 0, 5 do
      a:led(4, (i + off) + j * 7 - 7 - arc_off, 4)
    end
    a:led(4, (i + (lfo_focus - 1) * 7 - 6) + 50 - arc_off, 15)
  end
  -- draw lfo targets
  local tar = params:get(lfo_focus.."lfo_target")
  local name = string.sub(lfo_targets[tar], 2)
  for i = 1, 6 do
    a:led(4, -i + 7 + 33 - arc_off, (tar >= i + (i - 1) * 5 + 1 and tar <= i + (i - 1) * 5 + 6) and 15 or 2) -- track num
  end
  a:led(4, -1 + 33 - arc_off, name == "vol" and 15 or 6)
  a:led(4, -2 + 33 - arc_off, name == "pan" and 15 or 6)
  a:led(4, -3 + 33 - arc_off, name == "dub" and 15 or 6)
  a:led(4, -4 + 33 - arc_off, name == "transpose" and 15 or 6)
  a:led(4, -5 + 33 - arc_off, name == "rate_slew" and 15 or 6)
  a:led(4, -6 + 33 - arc_off, name == "cutoff" and 15 or 6)
  a:refresh()
end

function arc.env_delta(n, d)
  if n == 1 then
    params:delta(env_focus.."adsr_attack", d / 20)
  elseif n == 2 then
    params:delta(env_focus.."adsr_decay", d / 20)
  elseif n == 3 then
    params:delta(env_focus.."adsr_sustain", d / 20)
  elseif n == 4 then
    params:delta(env_focus.."adsr_release", d / 20)
  end
end

function arc.env_draw()
  a:all(0)
  -- draw adsr attack
  local attack = math.floor(util.linlin(0.1, 10, 0, 1, params:get(env_focus.."adsr_attack")) * 48) + 41
  a:led (1, 25 - arc_off, 5)
  a:led (1, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < attack - 64 then
      a:led(1, i - arc_off, 3)
    end
  end
  a:led(1, attack - arc_off, 15)
  -- draw adsr decay
  local decay = math.floor(util.linlin(0.1, 10, 0, 1, params:get(env_focus.."adsr_decay")) * 48) + 41
  a:led (2, 25 - arc_off, 5)
  a:led (2, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < decay - 64 then
      a:led(2, i - arc_off, 3)
    end
  end
  a:led(2, decay - arc_off, 15)
  -- draw adsr sustain
  local sustain = math.floor(params:get(env_focus.."adsr_sustain") * 48) + 41
  a:led (3, 25 - arc_off, 5)
  a:led (3, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < sustain - 64 then
      a:led(3, i - arc_off, 3)
    end
  end
  a:led(3, sustain - arc_off, 15)
  -- draw adsr release
  local release = math.floor(util.linlin(0.1, 10, 0, 1, params:get(env_focus.."adsr_release")) * 48) + 41
  a:led (4, 25 - arc_off, 5)
  a:led (4, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < release - 64 then
      a:led(4, i - arc_off, 3)
    end
  end
  a:led(4, release - arc_off, 15)
  a:refresh()
end

function arc.pattern_delta(n, d)
  -- noting yet
end

function arc.pattern_draw()
  a:all(0)
  -- light save mode
  a:refresh()
end

function arc.tape_delta(n, d)
  if n == 1 then
    arc_track_focus = util.clamp(arc_track_focus + d / 100, 1, 6)
    track_focus = math.floor(arc_track_focus)
    arc_splice_focus = track[track_focus].splice_focus
    render_splice()
    dirtygrid = true
  elseif n == 2 then
    arc_splice_focus = util.clamp(arc_splice_focus + d / 100, 1, 8)
    track[track_focus].splice_focus = math.floor(arc_splice_focus)
    render_splice()
    dirtygrid = true
  else
    local sens = 500
    local src = "arc"
    edit_splices(n, d, src, sens)
  end
end

function arc.tape_draw()
  a:all(0)
  -- draw track_focus
  for i = 1, 6 do
    local off = -13
    for j = 0, 5 do
      a:led(1, (i + off) + j * 7 - 7 - arc_off, 4)
    end
    a:led(1, (i + (track_focus - 1) * 7 - 6) + 50 - arc_off, 15)
  end
  -- draw splice_focus
  for i = 1, 6 do
    local off = -20
    for j = 0, 7 do
      a:led(2, (i + off) + j * 7 - 7 - arc_off, 4)
    end
    a:led(2, (i + (track[track_focus].splice_focus - 1) * 7 - 6) + 43 - arc_off, 15)
  end
  -- draw splice position
  local splice_s = tape[track_focus].splice[track[track_focus].splice_focus].s - tape[track_focus].s
  local splice_l = tape[track_focus].splice[track[track_focus].splice_focus].e - tape[track_focus].splice[track[track_focus].splice_focus].s
  local pos_startpoint = math.floor(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_s) * 58)
  local pos_endpoint = math.ceil(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * 58)
  a:led(3, -28 - arc_off, 6)
  a:led(3, 30 - arc_off, 6)
  for i = pos_startpoint, pos_startpoint + pos_endpoint do
    a:led(3, i + 1 - 29 - arc_off, 10)
  end
  -- draw splice size
  local win_startpoint = math.floor(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * -28)
  local win_endpoint = math.ceil(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * 28)
  a:led(4, -28 - arc_off, 6)
  a:led(4, 30 - arc_off, 6)
  for i = win_startpoint, win_endpoint do
    a:led(4, i + 1 - arc_off, 10)
  end
  a:refresh()
end

return arc
